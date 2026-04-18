
import http from '@ohos.net.http';
import { hilog } from '@kit.PerformanceAnalysisKit';

interface GLM_embedding {
  "index": number;
  "object": "embedding";
  "embedding": number[];
}

interface GLM_usage {
  "prompt_tokens": number;
  "completion_tokens": number;
  "total_tokens": number;
}

interface GLMApiResponse{
  "model": "<string>",
  "object": "list",
  "data": GLM_embedding[],
  "usage": GLM_usage
}

interface GMLRequestBody {
  model: string;
  input: string;
}

export class EmbeddingService {
  /**
   * 将文本转化为高维向量
   */
  private static readonly API_KEY = 'd936c39cd49f46ec92f406c8053265c4.aiL9grARhzJNHynM';
  private static readonly API_URL = 'https://open.bigmodel.cn/api/paas/v4/embeddings';

  /**
   * 调用智谱 GLM 将文本转化为高维语义向量
   * @param text 需要向量化的清洗后文本
   * @returns 包含浮点数的数字数组 (通常是 1024 维或以上)
   */
  static async getEmbedding(text: string): Promise<number[]> {
    // 如果文本为空，直接返回空数组，节约请求资源
    if (!text || text.trim() === '') {
      return [];
    }

    const httpRequest = http.createHttp();

    // 构造智谱 API 需要的请求体
    const requestBody: GMLRequestBody = {
      model: "embedding-2",
      input: text
    };

    try {
      hilog.info(0x0000, 'EmbeddingService', '正在呼叫智谱 GLM 生成文本向量...');

      const response = await httpRequest.request(EmbeddingService.API_URL, {
        method: http.RequestMethod.POST,
        header: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${EmbeddingService.API_KEY}`
        },
        extraData: JSON.stringify(requestBody),
        readTimeout: 10000,
        connectTimeout: 10000
      });

      if (response.responseCode === 200) {
        // 解析返回的 JSON 结果
        const resData:GLMApiResponse = JSON.parse(response.result as string);

        // 深入 JSON 结构，提取出那个珍贵的 number[] 数组
        const vector: number[] = resData.data[0].embedding;
        hilog.info(0x0000, 'EmbeddingService', `向量化成功，获取到 ${vector.length} 维数据`);
        return vector;
      } else {
        throw new Error(`智谱 API 请求失败，状态码: ${response.responseCode}, 详情: ${response.result}`);
      }
    } catch (error) {
      hilog.error(0x0000, 'EmbeddingService', `获取向量异常: ${JSON.stringify(error)}`);
      return [];
    } finally {
      // 释放底层 C++ 网络句柄
      httpRequest.destroy();
    }
  }
}