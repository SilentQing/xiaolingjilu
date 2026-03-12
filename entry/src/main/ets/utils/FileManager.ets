import fs from '@ohos.file.fs';
import { BusinessError } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { common } from '@kit.AbilityKit';

const TAG = 'FileManager';

export class FileManager {
  /**
   * 将系统图库的图片 URI 拷贝到应用本地沙箱
   * @param context UIAbility 的上下文，用于获取沙箱路径
   * @param sourceUri PhotoViewPicker 返回的图片 URI
   * @returns 返回拷贝后的沙箱绝对路径
   */
  static async copyImageToSandbox(context: Context, sourceUri: string): Promise<string> {
    try {
      // 生成沙箱内的唯一文件名 (利用时间戳避免重名)
      const fileName = `screenshot_${Date.now()}.jpg`;
      // 拼接目标沙箱路径 (context.filesDir 是应用内部的专属存储区)
      const destPath = `${context.filesDir}/${fileName}`;
      // 以只读模式打开系统图库中的源文件
      const srcFile = await fs.open(sourceUri, fs.OpenMode.READ_ONLY);
      // 将源文件直接拷贝到沙箱路径 (使用文件描述符 fd 拷贝最稳定)
      await fs.copyFile(srcFile.fd, destPath);
      // 务必关闭源文件，释放系统级内存句柄
      await fs.close(srcFile);

      hilog.info(0x0000, 'FileManager', `沙箱拷贝成功: ${destPath}`);
      return destPath;

    } catch (err) {
      hilog.error(0x0000, 'FileManager', `沙箱拷贝失败: ${JSON.stringify(err)}`);
      throw new Error("copy Image To Sandbox filed");
    }
  }

  private static instance: FileManager;

  static getInstance(): FileManager {
    if (!FileManager.instance) {
      FileManager.instance = new FileManager();
    }
    return FileManager.instance;
  }

  // 获取应用沙箱文件目录
  getAppFilesDir(): string {
    const context = getContext(this) as common.UIAbilityContext;
    return context.filesDir;
  }

  // 获取应用沙箱缓存目录
  getAppCacheDir(): string {
    const context = getContext(this) as common.UIAbilityContext;
    return context.cacheDir;
  }

  // 复制文件到应用沙箱
  async copyFileToSandbox(sourceUri: string, fileName: string): Promise<string> {
    try {
      // 生成目标文件路径
      const targetDir = `${this.getAppFilesDir()}/screenshots/`;
      const targetPath = `${targetDir}${fileName}`;

      // 确保目录存在
      await this.ensureDirectoryExists(targetDir);

      // 打开源文件
      const sourceFile = await fs.open(sourceUri, fs.OpenMode.READ_ONLY);

      // 创建目标文件
      const targetFile = await fs.open(targetPath, fs.OpenMode.CREATE | fs.OpenMode.READ_WRITE);

      // 复制文件内容
      const bufferSize = 4096;
      let buffer = new ArrayBuffer(bufferSize);
      let readLen = 0;
      let totalRead = 0;

      do {
        readLen = await fs.read(sourceFile.fd, buffer, { offset: totalRead });
        if (readLen > 0) {
          await fs.write(targetFile.fd, buffer, { offset: totalRead });
          totalRead += readLen;
        }
      } while (readLen === bufferSize);

      // 关闭文件
      await fs.close(sourceFile.fd);
      await fs.close(targetFile.fd);

      hilog.info(0xFF00, TAG, `文件复制成功: ${targetPath}`);
      return targetPath;

    } catch (error) {
      hilog.error(0xFF00, TAG, `文件复制失败: ${JSON.stringify(error)}`);
      throw new Error;
    }
  }

  // 创建缩略图
  async createThumbnail(sourceUri: string, fileName: string, maxWidth: number = 200, maxHeight: number = 200): Promise<string> {
    try {
      // 生成缩略图文件名
      const thumbnailName = `thumb_${fileName}`;
      const thumbnailPath = `${this.getAppCacheDir()}/thumbnails/${thumbnailName}`;

      // 确保目录存在
      await this.ensureDirectoryExists(`${this.getAppCacheDir()}/thumbnails/`);

      // 这里简化处理，实际应该使用图像处理库
      // 目前先直接复制原图作为缩略图
      const thumbnailUri = await this.copyFileToSandbox(sourceUri, thumbnailName);

      hilog.info(0xFF00, TAG, `缩略图创建成功: ${thumbnailUri}`);
      return thumbnailUri;

    } catch (error) {
      hilog.error(0xFF00, TAG, `缩略图创建失败: ${JSON.stringify(error)}`);
      // 如果缩略图创建失败，返回原图URI
      return sourceUri;
    }
  }

  // 确保目录存在
  private async ensureDirectoryExists(dirPath: string): Promise<void> {
    try {
      await fs.access(dirPath);
    } catch (error) {
      // 目录不存在，创建目录
      await fs.mkdir(dirPath, true);
    }
  }

  // 删除沙箱内的文件
  async deleteSandboxFile(filePath: string): Promise<void> {
    try {
      await fs.unlink(filePath);
      hilog.info(0xFF00, TAG, `文件删除成功: ${filePath}`);
    } catch (error) {
      hilog.error(0xFF00, TAG, `文件删除失败: ${JSON.stringify(error)}`);
    }
  }

  // 获取文件信息
  async getFileInfo(filePath: string): Promise<fs.Stat> {
    try {
      const fileInfo = await fs.stat(filePath);
      return fileInfo;
    } catch (error) {
      hilog.error(0xFF00, TAG, `获取文件信息失败: ${JSON.stringify(error)}`);
      throw new Error;
    }
  }
}
