// entry/src/main/ets/service/DeepSeekService.ets
import http from '@ohos.net.http';
import { RecordItemData, Category } from '../model/RecordItemData';
import { util } from '@kit.ArkTS';
import { hilog } from '@kit.PerformanceAnalysisKit';

interface ChatMessage {
  role: 'system' | 'user' | 'assistant';
  content: string;
}

interface ChatRequestBody {
  model: string;
  messages: ChatMessage[];
  temperature: number;
}

// 定义DeepSeek API响应接口
interface deepseek_message {
  role: string;
  content: string;
}

interface deepseek_res {
  index: number;
  message: deepseek_message;
  finish_reason: string;
}

interface deepseek_token {
  prompt_tokens: number;
  completion_tokens: number;
  total_tokens: number;
}

interface DeepSeekApiResponse {
  id: string;
  object: string;
  created: number;
  model: string;
  choices: Array<deepseek_res>;
  usage: deepseek_token;
}

// 定义AI解析结果接口
interface AiParseResult {
  title: string;
  summary: string;
  category: Category;
  tags: string[];
  highlightValue: string;
}

export class DeepSeekService {
  // 替换为你申请的真实 DeepSeek API Key
  private static readonly API_KEY = 'sk-f7c7187065df42f391319c22a045b24c';
  private static readonly API_URL = 'https://api.deepseek.com/chat/completions';

  /**
   * 调用 DeepSeek 大模型对 OCR 文本进行结构化信息抽取
   */
  static async analyzeText(rawText: string, imagePath: string): Promise<RecordItemData> {
    const httpRequest = http.createHttp();

    // 获取当前的绝对时间，并格式化为大模型容易理解的中文格式
    const now = new Date();
    const days = ['日', '一', '二', '三', '四', '五', '六'];
    const currentTimeStr = `${now.getFullYear()}年${now.getMonth() + 1}月${now.getDate()}日 星期${days[now.getDay()]} ${now.getHours().toString().padStart(2, '0')}:${now.getMinutes().toString().padStart(2, '0')}`;

    // System Prompt
    const systemPrompt = `你是一个出色的信息提取引擎。请阅读用户提供的 OCR 文本，提取核心信息并进行分类。

    【重要时间锚点】
    当前系统的真实时间是：${currentTimeStr}。
    如果文本中包含相对时间（如“明天”、“后天”、“下周三”、“今天下午”等），请务必基于上述【当前真实时间】进行严密的逻辑推算，将其转化为绝对时间。

    你必须严格按照以下 JSON 格式输出，不要包含任何 Markdown 标记（如 \`\`\`json）或其他解释性废话：
    {
      "title": "简短且高度概括的标题，最多10个字",
      "summary": "提炼文本的核心摘要，最多50个字",
      "category": "必须严格输出这三个英文单词之一：Bill, Schedule, Knowledge",
      "tags": ["标签1", "标签2", "最多生成3个相关标签"],
      "highlightValue": "如果是 Bill 提取出具体金额（如 ¥18.50），如果是 Schedule 提取出推算后的具体时间（请务必统一格式为 YYYY-MM-DD HH:mm），如果是 Knowledge 则填空字符串"
    }`;

    // 构造发给大模型的请求体
    const requestBody: ChatRequestBody = {
      model: "deepseek-chat", // 使用标准的 chat 模型即可，性价比最高
      messages: [
        { role: "system", content: systemPrompt },
        { role: "user", content: `这是提取出的OCR文本，请解析：\n${rawText}` }
      ],
      // 降低 temperature 可以让大模型的输出更具确定性，适合信息抽取任务
      temperature: 0.1
    };

    try {
      hilog.info(0x0000, 'DeepSeekService', '开始呼叫 DeepSeek 大模型...');
      const response = await httpRequest.request(DeepSeekService.API_URL, {
        method: http.RequestMethod.POST,
        header: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${DeepSeekService.API_KEY}`
        },
        extraData: JSON.stringify(requestBody),
        readTimeout: 15000, // 给大模型留足 15 秒的思考和生成时间
        connectTimeout: 15000
      });

      if (response.responseCode === 200) {
        // 解析 HTTP 响应
        hilog.info(0x000, 'deepseeksvice', `识别出的文字${JSON.stringify(response.result)}`)
        const resData: DeepSeekApiResponse = JSON.parse(response.result as string);

        const contentString = resData.choices[0].message.content;
        hilog.info(0x000, 'deepseeksvice', `识别出的文字${JSON.stringify(resData)}`)
        // 解析大模型返回的深层 JSON 字符串
        const aiResult: AiParseResult = JSON.parse(contentString);
        hilog.info(0x0000, 'DeepSeekService', `大模型解析成功: ${contentString}`);

        // 组装成我们的数据库对象
        return {
          id: util.generateRandomUUID(),
          imagePath: 'file://' + imagePath,
          title: aiResult.title || '未命名记录',
          // summary: aiResult.summary || rawText.substring(0, 50),
          summary: rawText,
          category: aiResult.category as Category || Category.Knowledge,
          tags: aiResult.tags || [],
          highlightValue: aiResult.highlightValue || '',
          createTime: new Date().toISOString()
        };
      } else {
        throw new Error(`API 请求失败，状态码: ${response.responseCode}`);
      }
    } catch (error) {
      hilog.error(0x0000, 'DeepSeekService', `大模型解析异常: ${JSON.stringify(error)}`);
      throw new Error("大模型解析异常");
    } finally {
      // 销毁请求，释放系统网络资源
      httpRequest.destroy();
    }
  }
}