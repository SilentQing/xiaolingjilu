import { textRecognition } from '@kit.CoreVisionKit';
import image from '@ohos.multimedia.image';
import fs from '@ohos.file.fs';
import { hilog } from '@kit.PerformanceAnalysisKit';

export class OcrService {
  /**
   * 调用系统 API 提取沙箱图片中的文字
   * @param sandboxPath 应用沙箱内的图片绝对路径
   * @returns 提取出的完整文本字符串
   */
  static async extractText(sandboxPath: string): Promise<string> {
    let file: fs.File | null = null;
    let imageSource: image.ImageSource | null = null;
    let pixelMap: image.PixelMap | null = null;

    try {
      file = fs.openSync(sandboxPath, fs.OpenMode.READ_ONLY);    // 以只读模式打开沙箱里的截图文件
      imageSource = image.createImageSource(file.fd);            // 创建图片源 (ImageSource)
      pixelMap = await imageSource.createPixelMap();             // 解码为底层像素图 (PixelMap)，这是 Core Vision 唯一认的格式
      // 构建视觉信息请求对象
      const visionInfo: textRecognition.VisionInfo = {
        pixelMap: pixelMap
      };
      // 设置 OCR 配置（开启方向检测，防止用户截图倒过来）
      const config: textRecognition.TextRecognitionConfiguration = {
        isDirectionDetectionSupported: true
      };
      // 调用 NPU 进行端侧原生识别
      hilog.info(0x0000, 'OcrService', '开始执行原生 OCR 识别...');
      const result = await textRecognition.recognizeText(visionInfo, config);
      // 返回识别出的完整字符串
      return result.value;

    } catch (err) {
      hilog.error(0x0000, 'OcrService', `OCR 解析失败: ${JSON.stringify(err)}`);
      throw new Error("OCR extract Text filed");
    } finally {
      // 手动释放 C++ 侧的内存句柄，防止应用内存泄漏崩溃
      if (pixelMap) {
        await pixelMap.release();
      }
      if (imageSource) {
        imageSource.release();
      }
      if (file) {
        fs.closeSync(file);
      }
    }
  }
}