// entry/src/main/ets/service/MindSporeService.ets
import mindSporeLite from '@ohos.ai.mindSporeLite';
import resourceManager from '@ohos.resourceManager';
import { hilog } from '@kit.PerformanceAnalysisKit';

export class MindSporeService {
  // 核心模型实例驻留内存，避免重复加载
  private static model: mindSporeLite.Model | null = null;
  private static isInitialized: boolean = false;


  /**
   * 初始化 MindSpore 引擎并加载 .ms 模型
   * 建议在应用启动 (EntryAbility) 或首页 aboutToAppear 中与 Tokenizer 一起调用
   */
  static async init(resMgr: resourceManager.ResourceManager): Promise<void> {
    if (MindSporeService.isInitialized) return;

    try {
      hilog.info(0x0000, 'MindSpore', '正在唤醒底层 AI 引擎，加载 bill_classifier.ms ...');

      // 1. 从 rawfile 读取 .ms 模型的二进制流
      const modelFile = await resMgr.getRawFileContent('ml/bill_classifier.ms');
      hilog.info(0x0000, 'MindSpore', `模型文件读取成功，大小: ${modelFile.byteLength} 字节`);


      // 2. 配置硬件上下文 (Context)
      let context: mindSporeLite.Context = {
        target: ['cpu'],
        cpu: {
          threadNum: 2, // 开 2 个线程跑 30MB 的模型，速度与功耗的完美平衡
          threadAffinityMode: 0
        }
      };
      hilog.info(0x0000, 'MindSpore', '硬件上下文配置完成，target: cpu, threadNum: 2');


      // 3. 将模型加载到底层引擎中
      hilog.info(0x0000, 'MindSpore', '开始调用 loadModelFromBuffer 加载模型...');
      MindSporeService.model = await mindSporeLite.loadModelFromBuffer(modelFile.buffer, context);
      // 加载成功后，检查模型是否有效
      if (MindSporeService.model) {
        // 尝试获取模型的基本信息（如果 API 支持）
        const inputs = MindSporeService.model.getInputs ? MindSporeService.model.getInputs() : [];
        const getWeights = MindSporeService.model.getWeights ? MindSporeService.model.getWeights() : [];
        hilog.info(0x0000, 'MindSpore', `模型加载成功！模型输入数量: ${inputs.length}, 输出数量getWeights: ${getWeights.length}`);
      } else {
        hilog.warn(0x0000, 'MindSpore', '模型加载返回空对象，可能加载未完全成功');
      }
      MindSporeService.isInitialized = true;

      hilog.info(0x0000, 'MindSpore', '模型加载成功！数字大脑已上线。');
    } catch (error) {
      hilog.error(0x0000, 'MindSpore', `引擎初始化崩溃: ${JSON.stringify(error)}`);
    }
  }

  /**
   * 执行毫秒级端侧推理
   * @param tokenIds 长度必须为 128 的数字数组 (由 Tokenizer 提供)
   * @returns true 代表是账单，false 代表是知识/日程
   */
  static async predictIsBill(tokenIds: number[]): Promise<boolean> {
    if (!MindSporeService.model) {
      hilog.error(0x0000, 'MindSpore', '模型未加载，降级返回 false');
      return false;
    }

    try {
      hilog.info(0x0000, 'MindSpore', '========== 开始推理 ==========');
      hilog.info(0x0000, 'MindSpore', `输入 tokenIds 长度: ${tokenIds.length}, 前10个token: ${tokenIds.slice(0, 10).join(', ')}`);


      const MAX_SEQ_LEN = 128;
      let paddedTokenIds: number[];
      if (tokenIds.length >= MAX_SEQ_LEN) {
        paddedTokenIds = tokenIds.slice(0, MAX_SEQ_LEN); // 截断
      } else {
        paddedTokenIds = [...tokenIds, ...new Array(MAX_SEQ_LEN - tokenIds.length).fill(0)]; // 填充0
      }
      hilog.info(0x0000, 'MindSpore', `处理后 tokenIds 长度: ${paddedTokenIds.length}`);
      // ==========================================
      // 步骤 A：构造 BERT 架构极其严格的三大输入矩阵
      // ==========================================


      // 1. attention_mask: 告诉模型哪些是有效字(1)，哪些是补齐的空位 0 (PAD)
      const attentionMask = tokenIds.map(id => id === 0 ? 0 : 1);
      hilog.debug(0x0000, 'MindSpore', `attentionMask 长度: ${attentionMask.length}, 前10个值: ${attentionMask.slice(0, 10).join(', ')}`);

      // 2. token_type_ids: 区分句子 A 和 B。由于我们只有一句话，全填 0 即可
      const tokenTypeIds: Array<number> = new Array(128).fill(0);
      hilog.debug(0x0000, 'MindSpore', `tokenTypeIds 长度: ${tokenTypeIds.length}`);

      // 获取模型输入端口
      let inputs:mindSporeLite.MSTensor[] = MindSporeService.model.getInputs();
      const targetShape = [1, MAX_SEQ_LEN];
      const newDims = inputs.map(() => targetShape);
      MindSporeService.model.resize(inputs, newDims);
      hilog.info(0x0000, 'MindSpore', `模型输入端口数量: ${inputs.length}`);
      inputs.forEach((tensor, idx) => {
        hilog.info(0x0000, 'MindSpore', `输入端口[${idx}] 名称: ${tensor.name}, 数据类型: ${tensor.dtype}, 形状: ${JSON.stringify(tensor.shape)}`);
      });

      // 遍历端口，根据名称精准装填数据 (防止转换工具打乱了输入顺序)
      // 注意：端侧推理框架通常使用 Int32Array 处理整数张量
      for (let i = 0; i < inputs.length; i++) {
        const tensor = inputs[i];
        if (tensor.name === 'input_ids') {
          const data = new Int32Array(tokenIds).buffer;
          tensor.setData(data);
        } else if (tensor.name === 'attention_mask') {
          tensor.setData(new Int32Array(attentionMask).buffer);
        } else if (tensor.name === 'token_type_ids') {
          tensor.setData(new Int32Array(tokenTypeIds).buffer);
        }
      }

      // ==========================================
      // 步骤 B：点火！执行前向传播 (Forward Propagation)
      // ==========================================
      const startTime = Date.now();
      let outputs = await MindSporeService.model.predict(inputs);
      const costTime = Date.now() - startTime;

      // ==========================================
      // 步骤 C：解析高维张量输出
      // ==========================================
      // LERT/BERT 输出的是一个名为 logits 的浮点数组 [score_class_0, score_class_1]
      let outData = new Float32Array(outputs[0].getData());

      // 这里的索引对应我们在 Python 里造数据时的 Label
      // 0: 其他 (日程/知识), 1: 账单 (Bill)
      const scoreOther = outData[0];
      const scoreBill = outData[1];

      hilog.info(0x0000, 'MindSpore', `推理耗时: ${costTime}ms | 非账单得分: ${scoreOther.toFixed(2)} | 账单得分: ${scoreBill.toFixed(2)}`);

      // 数学比对：哪个得分高，就是哪个类别
      return scoreBill > scoreOther;

    } catch (error) {
      hilog.error(0x0000, 'MindSpore', `推理过程发生异常: ${JSON.stringify(error)}`);
      return false; // 容错兜底
    }
  }
}