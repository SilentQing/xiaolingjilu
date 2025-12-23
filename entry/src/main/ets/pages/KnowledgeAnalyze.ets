import { promptAction, router } from '@kit.ArkUI';
import { ScreenshotItem } from '../model/types/ScreenshotItem';

// entry/src/main/ets/pages/KnowledgeAnalyze.ets
@Entry
@Component
struct KnowledgeAnalyze {
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
  @State recognizedText: string = '模拟识别文本：鸿蒙系统是华为自主研发的操作系统...';
  @State knowledgeTitle: string = '';
  @State tags: string = '';
  @State summary: string = '';

  aboutToAppear() {
    const params = router.getParams() as Record<string, string>;
    if (params?.['screenshotData']) {
      this.screenshotData = JSON.parse(params['screenshotData']);
      this.autoParseKnowledge();
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

        Text('知识分析')
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

      // 知识特定字段
      Text('知识标题：')
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .alignSelf(ItemAlign.Start)
        .margin({ top: 20 })

      TextInput({ placeholder: '输入知识标题', text: this.knowledgeTitle })
        .width('100%')
        .margin({ top: 8 })

      Text('标签：')
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .alignSelf(ItemAlign.Start)
        .margin({ top: 15 })

      TextInput({ placeholder: '用逗号分隔标签，如：技术,鸿蒙,操作系统', text: this.tags })
        .width('100%')
        .margin({ top: 8 })

      Text('摘要：')
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .alignSelf(ItemAlign.Start)
        .margin({ top: 15 })

      TextArea({ placeholder: '输入知识摘要', text: this.summary })
        .width('100%')
        .height(80)
        .margin({ top: 8 })

      // 操作按钮
      Button('保存知识')
        .width('100%')
        .height(50)
        .backgroundColor('#007AFF')
        .fontColor(Color.White)
        .margin({ top: 30 })
        .onClick(() => {
          this.saveKnowledge();
        })
    }
    .width('100%')
    .height('100%')
    .padding(16)
  }

  autoParseKnowledge() {
    // 知识解析逻辑
    if (this.recognizedText.includes('鸿蒙')) {
      this.knowledgeTitle = '鸿蒙系统介绍';
      this.tags = '技术,操作系统,华为';
    }
  }

  saveKnowledge() {
    promptAction.showToast({ message: '知识已保存' });
    router.back();
  }
}
