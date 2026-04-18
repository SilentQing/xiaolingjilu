// entry/src/main/ets/service/InformationExtractionService.ets
import { hilog } from '@kit.PerformanceAnalysisKit';
import { RecordItemData, Category } from '../model/RecordItemData';
import { TokenizerService } from './TokenizerService';
import { MindSporeService } from './MindSporeService';
import { DeepSeekService } from './DeepSeekService';
import { util } from '@kit.ArkTS';

export class InformationExtractionService {

  /**
   * 核心调度总线：处理 OCR 提取出的生肉文本
   * @param rawText OCR 识别出的全部原始文本
   * @param imagePath 截图的本地路径
   * @returns 结构化后的最终数据对象
   */
  static async processOcrText(rawText: string, imagePath: string): Promise<RecordItemData> {
    hilog.info(0x0000, 'Extraction', '--- 端云协同解析流水线启动 ---');

    // ==========================================
    // 本地端侧预处理与意图识别 (Edge AI)
    // ==========================================
    const startTime = Date.now();

    // 文本数字化 (查字典)
    const tokenIds = TokenizerService.tokenize(rawText);

    // NPU 毫秒级推理判断
    const isBill = await MindSporeService.predictIsBill(tokenIds);

    const edgeTime = Date.now() - startTime;
    hilog.info(0x0000, 'Extraction', `端侧意图识别完毕，耗时: ${edgeTime}ms，判定结果: ${isBill ? '【账单】' : '【非账单】'}`);

    // ==========================================
    // 动态路由分流 (Dynamic Routing)
    // ==========================================
    if (isBill) {
      // ----------------------------------------
      // 路由 A：纯本地提取路线 (极速、省钱、断网可用)
      // ----------------------------------------
      hilog.info(0x0000, 'Extraction', '进入端侧正则提取提取管线...');
      const amount = InformationExtractionService.extractAmountLocal(rawText);

      // 构造并返回本地生成的记录对象
      return {
        id: util.generateRandomUUID(),
        title: '本地账单记录',
        summary: `提取到一笔金额为 ${amount} 的消费流水。`,
        category: Category.Bill,
        tags: ['本地识别', '极速账单'],
        highlightValue: amount,
        createTime: new Date().toISOString(),
        imagePath: 'file://' + imagePath
      };

    } else {
      // ----------------------------------------
      // 路由 B：云端大模型深度推理路线 (高智商、需联网)
      // ----------------------------------------
      hilog.info(0x0000, 'Extraction', '进入云端 DeepSeek 深度推理管线...');
      try {
        const cloudResult = await DeepSeekService.analyzeText(rawText, imagePath);
        hilog.info(0x0000, 'Extraction', '云端大模型解析成功');
        return cloudResult;
      } catch (error) {
        hilog.error(0x0000, 'Extraction', `云端推理失败，降级为未分类本地备忘: ${JSON.stringify(error)}`);
        // 容错兜底机制
        return {
          id: util.generateRandomUUID(),
          title: '未分类截图',
          summary: rawText.substring(0, 50) + '...', // 截取前 50 个字作为摘要
          category: Category.Knowledge, // 默认丢进知识库
          tags: ['识别失败', '待处理'],
          highlightValue: '',
          createTime: new Date().toISOString(),
          imagePath: 'file://' + imagePath
        };
      }
    }
  }

  /**
   * 纯本地的高阶正则表达式，专门用于提取高噪 OCR 账单中的真实金额
   */
  private static extractAmountLocal(text: string): string {
    // 策略 1：精准狙击（最高优先级）。寻找明确代表“最终支付”的关键词
    // 匹配如：“实付:¥16.36”，“合计 4.60”，“到手¥11.4”，“支付成功¥4.00”
    const exactRegex = /(?:实付(?:款)?|合计|到手|支付(?:成功)?金额|支付成功)[\s:：]*[¥￥Y]*[\s]*(\d+(?:\.\d{1,2})?)/;
    const exactMatch = text.match(exactRegex);
    if (exactMatch && exactMatch[1]) {
      return `¥${parseFloat(exactMatch[1]).toFixed(2)}`;
    }

    // 策略 2：大海捞针。如果没有明确关键词，就把所有带货币符号的数字全找出来
    // 注意这里加了 \b 或者前面的限制，防止把长长的订单号带个 Y 给匹配进去
    const currencyRegex = /[¥￥Y]\s*(\d+(?:\.\d{1,2})?)/g;
    let match: RegExpExecArray | null;
    let amounts: number[] = [];

    while ((match = currencyRegex.exec(text)) !== null) {
      if (match[1]) {
        const num = parseFloat(match[1]);
        // 排除掉大于 100000 的离谱数字（极大概率是把单号当金额了）
        if (num > 0 && num < 100000) {
          amounts.push(num);
        }
      }
    }
    if (amounts.length > 0) {
      // 账单截图里，最大的那个数字往往就是最终的总价（因为比单价高）
      const maxAmount = Math.max(...amounts);
      return `¥${maxAmount.toFixed(2)}`;
    }

    // 兜底方案
    return '¥0.00';
  }
}