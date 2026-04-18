// entry/src/main/ets/service/TokenizerService.ets
import resourceManager from '@ohos.resourceManager';
import util from '@ohos.util';
import { hilog } from '@kit.PerformanceAnalysisKit';

export class TokenizerService {
  // 核心字典，将文字映射为数字 ID
  private static vocabMap: Map<string, number> = new Map();
  private static isInitialized: boolean = false;

  // BERT/LERT 模型的特殊 Token ID 规范
  private static readonly CLS_ID = 101; // 句首标志
  private static readonly SEP_ID = 102; // 句尾标志
  private static readonly UNK_ID = 100; // 未知字/乱码标志 (Unknown)
  private static readonly PAD_ID = 0;   // 占位填充标志 (Padding)

  // 我们在导出 ONNX 时锁定的最大序列长度
  private static readonly MAX_LEN = 128;

  /**
   * 初始化引擎：从系统底层的 rawfile 中把字典加载到内存
   * 注意：这个方法需要在应用启动或者进入主页时调用一次
   */
  static async init(resMgr: resourceManager.ResourceManager): Promise<void> {
    if (TokenizerService.isInitialized) return;

    try {
      hilog.info(0x0000, 'Tokenizer', '开始加载 vocab.txt 字典...');

      // 读取 rawfile 中的字典文件内容 (返回的是 Uint8Array 字节流)
      const rawData = await resMgr.getRawFileContent('ml/vocab.txt');

      // 利用系统工具将字节流解码为 UTF-8 字符串
      const textDecoder = util.TextDecoder.create('utf-8');
      const vocabText = textDecoder.decodeWithStream(rawData);

      // 按行分割并构建内存 Map 字典
      const lines = vocabText.split('\n');
      for (let i = 0; i < lines.length; i++) {
        const token = lines[i].trim();
        if (token) {
          // 在 vocab.txt 中，行号 i 正好严格对应这个字的 Token ID
          TokenizerService.vocabMap.set(token, i);
        }
      }

      TokenizerService.isInitialized = true;
      hilog.info(0x0000, 'Tokenizer', `分词器初始化成功！共装载 ${TokenizerService.vocabMap.size} 个词汇映射`);
    } catch (error) {
      hilog.error(0x0000, 'Tokenizer', `加载 vocab.txt 彻底失败: ${JSON.stringify(error)}`);
    }
  }

  /**
   * 核心功能：将 OCR 出来的字符串转化为长度为 128 的数字数组
   */
  static tokenize(text: string): number[] {
    if (!TokenizerService.isInitialized) {
      hilog.error(0x0000, 'Tokenizer', '致命错误：Tokenizer 未初始化，直接返回全 0 数组');
      return new Array(TokenizerService.MAX_LEN).fill(TokenizerService.PAD_ID);
    }

    // 将英文字母统一转小写，因为中文 BERT 字典里的英文字母通常只有小写
    const lowerText = text.toLowerCase();

    // 初始化数组，第一位强制放入 [CLS]
    let tokenIds: number[] = [TokenizerService.CLS_ID];

    // 逐字切分文本并查字典
    for (let i = 0; i < lowerText.length; i++) {
      const char = lowerText[i];

      // 跳过无意义的空白符
      if (char.trim() === '') continue;

      // 查字典，如果遇到连字典都不认识的终极乱码，就给它赋予 [UNK] 身份
      const id = TokenizerService.vocabMap.get(char);
      tokenIds.push(id !== undefined ? id : TokenizerService.UNK_ID);

      // 截断机制：如果长度达到 127，就必须停下，因为要给最后的 [SEP] 留一个位置
      if (tokenIds.length >= TokenizerService.MAX_LEN - 1) {
        break;
      }
    }

    // 文本结束，放入 [SEP]
    tokenIds.push(TokenizerService.SEP_ID);

    // 填充机制：如果长度不够 128，用 [PAD] 把剩下的位置全部用 0 填满
    while (tokenIds.length < TokenizerService.MAX_LEN) {
      tokenIds.push(TokenizerService.PAD_ID);
    }

    return tokenIds;
  }
}