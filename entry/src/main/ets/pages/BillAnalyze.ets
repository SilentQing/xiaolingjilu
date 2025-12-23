import { ScreenshotItem } from '../model/types/ScreenshotItem';
import { promptAction, router } from '@kit.ArkUI';

@Entry
@Component
struct BillAnalyze {
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
  @State recognizedText: string = '模拟识别文本：微信支付¥105.50，商户：星巴克...';
  @State amount: string = '';
  @State merchant: string = '';
  @State date: string = '';
  @State category: string = '餐饮';

  aboutToAppear() {
    const params = router.getParams() as Record<string, string>;
    if (params?.['screenshotData']) {
      this.screenshotData = JSON.parse(params['screenshotData']);
      this.autoParseBill();
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

        Text('账单分析')
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

      // 账单特定字段
      Text('金额：')
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .alignSelf(ItemAlign.Start)
        .margin({ top: 20 })

      TextInput({ placeholder: '输入金额', text: this.amount })
        .width('100%')
        .margin({ top: 8 })
        .type(InputType.Number)

      Text('平台：')
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .alignSelf(ItemAlign.Start)
        .margin({ top: 15 })

      TextInput({ placeholder: '输入平台名称', text: this.merchant })
        .width('100%')
        .margin({ top: 8 })

      Text('日期：')
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .alignSelf(ItemAlign.Start)
        .margin({ top: 15 })

      TextInput({ placeholder: '选择日期', text: this.date })
        .width('100%')
        .margin({ top: 8 })

      Text('分类：')
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .alignSelf(ItemAlign.Start)
        .margin({ top: 15 })

      // 账单分类选择
      Row({ space: 10 }) {
        this.BillCategory('餐饮', '餐饮')
        this.BillCategory('购物', '购物')
        this.BillCategory('交通', '交通')
        this.BillCategory('其他', '其他')
      }
      .width('100%')
      .margin({ top: 8 })

      // 操作按钮
      Button('保存账单')
        .width('100%')
        .height(50)
        .backgroundColor('#FF9500')
        .fontColor(Color.White)
        .margin({ top: 30 })
        .onClick(() => {
          this.saveBill();
        })
    }
    .width('100%')
    .height('100%')
    .padding(16)
  }

  @Builder
  BillCategory(name: string, value: string) {
    Button(name)
      .padding({ left: 15, right: 15, top: 8, bottom: 8 })
      .backgroundColor(this.category === value ? '#FF9500' : '#F5F5F5')
      .fontColor(this.category === value ? Color.White : '#666666')
      .borderRadius(15)
      .onClick(() => {
        this.category = value;
      })
  }

  autoParseBill() {
    // 账单解析逻辑
    const text = this.recognizedText;
    const amountMatch = text.match(/¥(\d+\.?\d*)/);
    if (amountMatch) {
      this.amount = amountMatch[1];
    }

    if (text.includes('星巴克')) {
      this.merchant = '星巴克';
      this.category = '餐饮';
    }

    this.date = '2024-08-21';
  }

  saveBill() {
    promptAction.showToast({ message: '账单已保存' });
    router.back();
  }
}
