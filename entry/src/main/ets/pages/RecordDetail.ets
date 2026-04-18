import router from '@ohos.router';
import { RecordItemData, Category } from '../model/RecordItemData';
import { PromptAction } from '@kit.ArkUI';
import { RdbManager } from '../dao/RdbManager';
import { FileManager } from '../utils/FileManager';

@Entry
@Component
struct RecordDetail {
  // 接收从列表页传过来的数据
  @State record: RecordItemData | null = null;

  // 控制全屏图片预览的状态
  @State isPreviewOpen: boolean = false;

  uiContext: UIContext | undefined = undefined;
  promptAction: PromptAction = this.getUIContext().getPromptAction();

  // 页面生命周期：获取路由参数
  aboutToAppear() {
    const params = router.getParams() as Record<string, Object>;
    if (params && params.recordInfo) {
      this.record = params.recordInfo as RecordItemData;
    }
    this.uiContext = this.getUIContext();
  }

  // 辅助方法：获取分类颜色
  private getCategoryColor(): string {
    if (!this.record) return '#000000';
    switch (this.record.category) {
      case Category.Bill: return '#FF5E5E';
      case Category.Schedule: return '#007DFF';
      case Category.Knowledge: return '#4CAF50';
      default: return '#666666';
    }
  }

  private async handleDelete() {
    if (!this.record) return;


    // 弹出系统级二次确认弹窗防误触
    this.promptAction.showDialog({
      title: '删除记录',
      message: '确定要删除这条记录吗？删除后将无法恢复，且相关截图也会被清除。',
      buttons: [
        { text: '取消', color: '#666666' },
        { text: '彻底删除', color: '#FF5E5E' } // 危险操作使用红色警示
      ]
    })
      .then(async (data) => {
      // data.index 为 1 表示用户点击了第二个按钮（彻底删除）
      if (data.index === 1) {
        try {
          // 删库 + 删图
          await RdbManager.getInstance().deleteRecord(this.record!.id);
          await FileManager.deleteSandboxFile(this.record!.imagePath);

          this.promptAction.showToast({ message: '删除成功' });

          // 返回上一页（列表页或搜索页）
          router.back();
        } catch (error) {
          this.promptAction.showToast({ message: '删除过程中发生异常' });
        }
      }
    })
      .catch((err: Error) => {
        console.error('showDialog error: ' + err);
      });
  }


  build() {
    // 使用 Stack 布局，方便把全屏图片盖在最上面
    Stack() {
      // --- 底层：常规详情页面 ---
      Column() {
        // 自定义顶部导航栏
        Row() {
          Image($r('app.media.ic_back')) // 请准备一个返回箭头图标
            .width(24).height(24)
            .onClick(() => router.back())

          Text('记录详情')
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .margin({ left: 16 })
            .layoutWeight(1)

          // 右上角的删除按钮
          Image($r('app.media.ic_delete')) // 垃圾桶图标
            .width(24).height(24)
            .fillColor('#FF5E5E')
            .onClick(() => {
              this.handleDelete();
            })
        }
        .width('100%')
        .height(56)
        .padding({ left: 16, right: 16 })
        .backgroundColor(Color.White)

        if (this.record) {
          // 可滚动的内容区
          Scroll() {
            Column({ space: 16 }) {

              // 顶部：大图裁剪预览（点击可全屏）
              if(!this.isPreviewOpen) {
                Image(this.record.imagePath)
                  .width('100%')
                  .height(200)
                  .objectFit(ImageFit.Cover) // 缩放裁剪填满
                  .borderRadius(12)
                  // 跨页面转场（列表进来时的动画）
                  .sharedTransition(`shared_img_${this.record.id}`, {
                    duration: 350,
                    curve: Curve.FastOutSlowIn,
                    delay: 0
                  })
                  // 同页面几何转场 ID
                  .geometryTransition(`zoom_img_${this.record.id}`)
                  .onClick(() => {
                    // 点击图片，打开全屏预览
                    this.uiContext?.animateTo({ duration: 300, curve: Curve.FastOutSlowIn } , () => {
                      this.isPreviewOpen = true;
                    })
                  })
              } else {
                // 当图片全屏时，原地留一个透明的占位框，防止下方的文本突然往上顶
                Row().width('100%').height(200)
              }


              // 标题与高光数据区
              Row() {
                Column() {
                  Row() {
                    Text(this.record.category === Category.Bill ? '账单' :
                      this.record.category === Category.Schedule ? '日程' : '知识')
                      .fontSize(12)
                      .fontColor(Color.White)
                      .backgroundColor(this.getCategoryColor())
                      .padding({ left: 8, right: 8, top: 4, bottom: 4 })
                      .borderRadius(4)
                      .margin({ right: 8 })

                    Text(this.record.title)
                      .fontSize(22)
                      .fontWeight(FontWeight.Bold)
                      .layoutWeight(1)
                  }.width('100%')

                  Text(`收录于 ${this.record.createTime}`)
                    .fontSize(12)
                    .fontColor('#999999')
                    .margin({ top: 8 })
                }.layoutWeight(1).alignItems(HorizontalAlign.Start)

                // 核心提取数值（如金额）
                if (this.record.highlightValue) {
                  Text(this.record.highlightValue)
                    .fontSize(24)
                    .fontWeight(FontWeight.Bolder)
                    .fontColor(this.getCategoryColor())
                }
              }
              .width('100%')
              .padding(16)
              .backgroundColor(Color.White)
              .borderRadius(12)

              // 完整文本展示区
              Column() {
                Text('OCR 提取文本')
                  .fontSize(14)
                  .fontWeight(FontWeight.Medium)
                  .fontColor('#666666')
                  .margin({ bottom: 12 })
                  .width('100%')

                Text(this.record.summary)
                  .fontSize(16)
                  .lineHeight(24)
                  .fontColor('#333333')
                  .width('100%')
                  .copyOption(CopyOptions.LocalDevice)
              }
              .width('100%')
              .padding(16)
              .backgroundColor(Color.White)
              .borderRadius(12)

            }
            .padding(16)
          }
          .layoutWeight(1)
          .scrollBar(BarState.Auto)
        }
      }
      .width('100%')
      .height('100%')
      .backgroundColor('#F2F4F5') // 页面底层灰色

      // --- 顶层：全屏图片预览 (通过 zIndex 覆盖) ---
      if (this.isPreviewOpen && this.record) {
        Column() {
          Image(this.record.imagePath)
            .width('100%')
            .height('100%')
            .objectFit(ImageFit.Contain) // 全屏模式下保持比例，不裁剪
            .geometryTransition(`zoom_img_${this.record.id}`)
            .onClick(() => {
              this.uiContext?.animateTo({ duration: 300, curve: Curve.FastOutSlowIn }, () => {
                this.isPreviewOpen = false;
              })
            })
        }
        .width('100%')
        .height('100%')
        .backgroundColor('#FF000000') // 纯黑色背景
        .zIndex(999) // 确保在最顶层
        .transition(TransitionEffect.OPACITY.animation({ duration: 300 }))
      }
    }
    .width('100%')
    .height('100%')
  }
}