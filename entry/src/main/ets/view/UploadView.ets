import { photoAccessHelper } from "@kit.MediaLibraryKit";
import { hilog } from "@kit.PerformanceAnalysisKit";

@Entry
@Component
export struct UploadView {
  @State selectedImageUri: string = ''; // 存放选中的图片 URI
  @State isProcessing: boolean = false; // 内部状态：是否正在识别

  build() {
    Column() {
      Text('小玲记录 - 智能提取')
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .margin(20)

      // 动态显示区：未选图时显示上传按钮，选中后显示图片预览
      if (this.selectedImageUri === '') {
        Column() {
          Image($r('app.media.upload_placeholder'))
            .width(80).height(80)
          Text('点击从相册选择截图')
            .fontColor('#666666')
            .fontSize(16)
        }
        .width('85%')
        .height(300)
        .backgroundColor('#F2F4F5')
        .borderRadius(16)
        .justifyContent(FlexAlign.Center)
        // 绑定点击事件拉起相册
        .onClick(() => this.pickScreenshot())

      } else {
        Column() {
          // 鸿蒙的 Image 组件可以直接渲染 Picker 返回的 file:// URI
          Image(this.selectedImageUri)
            .width('85%')
            .height(300)
            .objectFit(ImageFit.Contain)
            .borderRadius(16)
            .backgroundColor('#E8E8E8')
            .margin({ bottom: 20 })

          if (this.isProcessing) {
            // 识别中的 Loading
            LoadingProgress().width(48).height(48).color('#007DFF')
            Text('AI 正在拼命读取中...').fontSize(14).fontColor('#999999').margin({ top: 8 })
          } else {
            Row() {
              Button('重新选择')
                .backgroundColor('#E5E5E5')
                .fontColor('#333333')
                .onClick(() => this.pickScreenshot())

              Button('开始提取文字')
                .backgroundColor('#007DFF')
                .onClick(() => this.startOcr())
            }
          }
        }.width("100%")
      }
    }
    .width('100%')
    .height('100%')
  }

  // 核心方法：拉起系统相册选择截图
  async pickScreenshot() {
    try {

      let photoSelectOptions = new photoAccessHelper.PhotoSelectOptions();                    // 实例化照片选择器配置
      photoSelectOptions.MIMEType = photoAccessHelper.PhotoViewMIMETypes.IMAGE_TYPE;          // 限制只能选图片
      photoSelectOptions.maxSelectNumber = 1;                                                 // MVP 阶段每次只处理一张截图
      let photoPicker = new photoAccessHelper.PhotoViewPicker();                              // 调用相册选择
      let photoSelectResult = await photoPicker.select(photoSelectOptions);                   // 拉起选择器并等待用户操作
      //  处理返回结果
      if (photoSelectResult && photoSelectResult.photoUris.length > 0) {
        // 获取选中图片的系统 URI (格式类似 file://media/Photo/...)
        this.selectedImageUri = photoSelectResult.photoUris[0];
        hilog.info(0x0000, 'UploadView', `图片选择成功: ${this.selectedImageUri}`);
      }
    } catch (err) {
      hilog.error(0x0000, 'UploadView', `图片选择失败: ${JSON.stringify(err)}`);
    }
  }

  // 模拟 OCR 处理逻辑
  startOcr() {
    if (!this.selectedImageUri) return;
    this.isProcessing = true;

    setTimeout(() => {
      this.isProcessing = false;
      // 这里未来会跳转到识别结果页
    }, 2000);
  }
}