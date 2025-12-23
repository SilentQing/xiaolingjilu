import fs from '@ohos.file.fs';
import { BusinessError } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { common } from '@kit.AbilityKit';

const TAG = 'FileManager';

export class FileManager {
  private static instance: FileManager;
  private context = this.getUIContext().getHostContext() as common.UIAbilityContext;


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
