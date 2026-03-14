import { photoAccessHelper } from "@kit.MediaLibraryKit";
import { hilog } from "@kit.PerformanceAnalysisKit";
import { FileManager } from "../utils/FileManager";
import { common } from "@kit.AbilityKit";
import { OcrService } from "../service/OcrService";
import { RdbManager } from "../dao/RdbManager";
import { Category, RecordItemData } from "../model/RecordItemData";
import { util } from "@kit.ArkTS";
import { PromptAction } from "@kit.ArkUI";
import { DeepSeekService } from "../service/DeepSeekService";
import { EmbeddingService } from "../service/EmbeddingService";


@Entry
@Component
export struct UploadView {
  @State selectedImageUri: string = ''; // 存放选中的图片 URI
  @State isProcessing: boolean = false; // 内部状态：是否正在识别

  // 用于底部弹窗的状态变量
  @State isShowConfirmSheet: boolean = false; // 控制面板显示/隐藏
  @State pendingRecord: RecordItemData | null = null; // 暂存识别出的原始记录

  // 用于表单双向绑定的编辑状态
  @State editTitle: string = '';
  @State editSummary: string = '';
  @State editCategory: Category = Category.Knowledge;

  // 获取当前组件的上下文
  private context = this.getUIContext().getHostContext() as common.UIAbilityContext;
  uiContext: UIContext = this.getUIContext();
  promptAction: PromptAction = this.uiContext.getPromptAction();

  // 自定义底部面板的 UI 构建器
  @Builder
  ConfirmSheetBuilder() {
    Column() {
      // 面板标题
      Row() {
        Text('确认并完善信息')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
      }
      .width('100%')
      .padding({ top: 16, bottom: 16 })
      .justifyContent(FlexAlign.Center)

      // 表单区
      Column({ space: 16 }) {
        // 分类选择 (用胶囊按钮组模拟)
        Row({ space: 12 }) {
          Text('分类').fontSize(16).fontWeight(FontWeight.Medium).width(50)
          this.CategoryButton('账单', Category.Bill)
          this.CategoryButton('日程', Category.Schedule)
          this.CategoryButton('知识', Category.Knowledge)
        }.width('100%')

        // 标题输入框
        Row() {
          Text('标题').fontSize(16).fontWeight(FontWeight.Medium).width(50)
          TextInput({ text: this.editTitle, placeholder: '请输入简短标题' })
            .layoutWeight(1)
            .onChange((value: string) => { this.editTitle = value })
        }.width('100%')

        // 摘要输入框 (多行文本)
        Column() {
          Text('摘要内容').fontSize(16).fontWeight(FontWeight.Medium).width('100%').margin({ bottom: 8 })
          TextArea({ text: this.editSummary })
            .width('100%')
            .height(120) // 给足够的高度看完整理后的文字
            .onChange((value: string) => { this.editSummary = value })
        }.width('100%')
      }
      .padding({ left: 20, right: 20 })
      .layoutWeight(1)

      // 底部操作按钮
      Row({ space: 16 }) {
        Button('取消')
          .backgroundColor('#F2F2F2')
          .fontColor('#333333')
          .layoutWeight(1)
          .onClick(() => { this.isShowConfirmSheet = false })

        Button('保存记录')
          .backgroundColor('#007DFF')
          .layoutWeight(1)
          .onClick(() => this.saveRecord())
      }
      .width('100%')
      .padding(20)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Color.White)
    .borderRadius({ topLeft: 24, topRight: 24 }) // 圆角设计更显原生
  }

  // 辅助构建器：用于渲染分类按钮
  @Builder
  CategoryButton(label: string, category: Category) {
    Text(label)
      .fontSize(14)
      .fontColor(this.editCategory === category ? Color.White : '#666666')
      .backgroundColor(this.editCategory === category ? '#007DFF' : '#F2F2F2')
      .padding({ left: 16, right: 16, top: 8, bottom: 8 })
      .borderRadius(16)
      .onClick(() => { this.editCategory = category })
  }

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
    // --- 核心挂载点：绑定底部面板 ---
    .bindSheet($$this.isShowConfirmSheet, this.ConfirmSheetBuilder(), {
      height: SheetSize.MEDIUM,  // 占据屏幕的中等高度 (大约一半)
      dragBar: true,             // 顶部显示一个小灰条，提示用户可以下拉关闭
      backgroundColor: Color.White,
      showClose: false           // 隐藏系统自带的关闭按钮，我们自己画了“取消”
    })
  }

  // 拉起系统相册选择截图
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


  // OCR 处理逻辑
  async startOcr() {
    if (!this.selectedImageUri) return;
    this.isProcessing = true;

    try {
      const sandboxPath = await FileManager.copyImageToSandbox(this.context, this.selectedImageUri);  // 拷贝图片到沙箱
      const rawText = await OcrService.extractText(sandboxPath);                                      // 调用侧端NPL原生 API 提取纯文本
      // const newRecord = this.analyzeTextWithCustomRules(rawText, sandboxPath);                     // 基于自定义规则对文本进行分类和提取
      const  newRecord = await DeepSeekService.analyzeText(rawText, sandboxPath)                      // 使用云端大模型对文本进行分类

      // 将 AI 提取的结果同步给编辑状态
      this.pendingRecord = newRecord;
      hilog.info(0x000, 'newRecord', `${JSON.stringify(newRecord)}`)
      this.editTitle = newRecord.title;
      this.editSummary = newRecord.summary;
      this.editCategory = newRecord.category;

      // 把标题、摘要和分类拼起来去获取语义向量
      const textToEmbed = `[${newRecord.category}] ${newRecord.title}: ${newRecord.summary}`;
      const vector = await EmbeddingService.getEmbedding(textToEmbed);
      newRecord.embedding = vector

      // 关闭加载动画，拉起底部确认面板
      this.isProcessing = false;
      this.isShowConfirmSheet = true;

      this.selectedImageUri = '';
      // 这里可以加一个 Toast 提示 "提取成功"
    } catch (error) {
      this.isProcessing = false;
      this.promptAction.openToast({ message: '文字提取失败，请重试' });
    }
  }

  /**
   * 使用自定义正则规则，将杂乱的 OCR 文本结构化为数据库对象
   */
  private analyzeTextWithCustomRules(text: string, path: string): RecordItemData {
    hilog.info(0x000, 'imagePath', `get path: ${path}`)
    // 默认兜底分类为“知识”
    let category: Category = Category.Knowledge;
    let highlightValue = '';

    // 账单匹配规则（寻找金额）
    const billRegex = /(?:支付|金额|合计|¥|￥)\s*(\d+(\.\d{1,2})?)/;
    const billMatch = text.match(billRegex);

    // 日程匹配规则（寻找日期时间）
    const scheduleRegex = /(?:明天|后天|周[一二三四五六日]|\d{1,2}月\d{1,2}日)\s*\d{1,2}:\d{2}/;
    const scheduleMatch = text.match(scheduleRegex);

    if (billMatch) {
      category = Category.Bill;
      highlightValue = billMatch[1]; // 提取出的具体金额数字
    } else if (scheduleMatch) {
      category = Category.Schedule;
      highlightValue = scheduleMatch[0]; // 提取出的具体时间段
    }

    // 简单截取前 10 个字作为标题，前 50 个字作为摘要
    const cleanText = text.replace(/\s+/g, ' '); // 替换换行和多余空格
    const title = cleanText.substring(0, 10);
    const summary = cleanText.substring(0, 50) + (cleanText.length > 50 ? '...' : '');

    return {
      id: util.generateRandomUUID(), // 生成唯一 ID
      imagePath: 'file://' + path,
      title: title,
      summary: summary,
      category: category,
      tags: [], // 初始标签为空，留给用户后续手动在详情页加
      highlightValue: highlightValue,
      createTime: new Date().toISOString()
    };


  }

  // 保存入库方法
  async saveRecord() {
    if (!this.pendingRecord) return;

    // 把用户修改后的最新值覆盖回去

    this.pendingRecord.title = this.editTitle;
    this.pendingRecord.summary = this.editSummary;
    this.pendingRecord.category = this.editCategory;

    try {
      // 存入 SQLite
      await RdbManager.getInstance().insertRecord(this.pendingRecord);                // 将结构化数据写入 SQLite 数据库

      // 关闭面板，清空当前页面状态
      this.isShowConfirmSheet = false;
      this.selectedImageUri = '';               // 清空界面，准备下一次识别
      this.pendingRecord = null;

      this.promptAction.showToast({ message: '保存成功！' });
    } catch (err) {
      this.promptAction.showToast({ message: '保存失败' });
    }
  }
}