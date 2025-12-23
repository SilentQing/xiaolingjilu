import { ScreenshotItem } from '../model/types/ScreenshotItem';
import { promptAction, router } from '@kit.ArkUI';

@Entry
@Component
struct ScheduleAnalyze {
  @State screenshotData: ScreenshotItem = {
    id: 0,
    thumbnail: '',
    importTime: 0,
    status: '',
    fileName: '',
    uri: '',
    category: '',
    createdTime: 0
  };
  @State recognizedText: string = '模拟识别文本：明天上午10点团队会议，地点：A会议室';
  @State eventTitle: string = '';
  @State eventTime: string = '';
  @State eventLocation: string = '';

  aboutToAppear() {
    const params = router.getParams() as Record<string, string>;
    if (params?.['screenshotData']) {
      this.screenshotData = JSON.parse(params['screenshotData']);
      // 模拟自动解析
      this.autoParseSchedule();
    }
  }

  build() {
    Column() {
      // 顶部导航
      Row() {
        Text() {
          SymbolSpan($r('sys.symbol.chevron_left'))
        }
          .width(24)
          .height(24)
          .onClick(() => {
            router.back();
          })

        Text('日程分析')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .layoutWeight(1)
          .textAlign(TextAlign.Center)
      }
      .width('100%')
      .padding({ bottom: 20 })

      // 截图预览
      Image(this.screenshotData.thumbnail || $r('app.media.sample1'))
        .width('100%')
        .height(200)
        .objectFit(ImageFit.Cover)
        .borderRadius(8)

      // 识别文本
      Text('识别文本：')
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .alignSelf(ItemAlign.Start)
        .margin({ top: 20 })

      TextArea({ text: this.recognizedText })
        .width('100%')
        .height(100)
        .margin({ top: 8 })
        .onChange((value: string) => {
          this.recognizedText = value;
        })

      // 日程特定字段
      Text('事件标题：')
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .alignSelf(ItemAlign.Start)
        .margin({ top: 20 })

      TextInput({ placeholder: '输入事件标题', text: this.eventTitle })
        .width('100%')
        .margin({ top: 8 })
        .onChange((value: string) => {
          this.eventTitle = value;
        })

      Text('事件时间：')
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .alignSelf(ItemAlign.Start)
        .margin({ top: 15 })

      TextInput({ placeholder: '例如：明天10:00', text: this.eventTime })
        .width('100%')
        .margin({ top: 8 })
        .onChange((value: string) => {
          this.eventTime = value;
        })

      Text('事件地点：')
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .alignSelf(ItemAlign.Start)
        .margin({ top: 15 })

      TextInput({ placeholder: '输入事件地点', text: this.eventLocation })
        .width('100%')
        .margin({ top: 8 })
        .onChange((value: string) => {
          this.eventLocation = value;
        })

      // 操作按钮
      Row() {
        Button('取消')
          .layoutWeight(1)
          .backgroundColor('#F5F5F5')
          .fontColor('#666666')
          .onClick(() => {
            router.back();
          })

        Button('保存日程')
          .layoutWeight(1)
          .margin({ left: 12 })
          .backgroundColor('#34C759')
          .fontColor(Color.White)
          .onClick(() => {
            this.saveSchedule();
          })
      }
      .width('100%')
      .margin({ top: 30 })
    }
    .width('100%')
    .height('100%')
    .padding(16)
  }

  autoParseSchedule() {
    // 模拟从文本中自动解析日程信息
    const text = this.recognizedText.toLowerCase();
    if (text.includes('会议')) {
      this.eventTitle = '团队会议';
    }
    if (text.includes('10点') || text.includes('10:00')) {
      this.eventTime = '明天 10:00';
    }
    if (text.includes('a会议室')) {
      this.eventLocation = 'A会议室';
    }
  }

  saveSchedule() {
    // 保存日程逻辑
    promptAction.showToast({ message: '日程已保存' });
    // 返回首页并刷新
    router.back();
  }
}
