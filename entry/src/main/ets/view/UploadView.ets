@Entry
@Component
export struct UploadView {
  @State isProcessing: boolean = false; // 内部状态：是否正在识别

  build() {
    Column() {
      Text('小玲记录 - 智能提取')
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .margin(20)

      // 上传占位区
      Stack() {
        Column() {
          Image($r('app.media.upload_placeholder'))
            .width(80).height(80)
          Text('点击上传截图').margin({ top: 10 })
        }
        .visibility(this.isProcessing ? Visibility.Hidden : Visibility.Visible)

        // 识别中的加载动画
        if (this.isProcessing) {
          LoadingProgress().width(60).height(60).color('#007DFF')
        }
      }
      .width('90%')
      .height(300)
      .backgroundColor('#F1F3F5')
      .borderRadius(16)
      .onClick(() => {
        this.startOcr();
      })
    }
    .width('100%')
    .height('100%')
  }

  // 模拟 OCR 处理逻辑
  startOcr() {
    this.isProcessing = true;
    setTimeout(() => {
      this.isProcessing = false;
      // 这里未来会跳转到识别结果页
    }, 2000);
  }
}