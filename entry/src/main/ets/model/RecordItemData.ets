export enum Category {
  Bill = 'Bill',
  Schedule = 'Schedule',
  Knowledge = 'Knowledge'
}

export interface RecordItemData {
  id: string;
  imagePath: string;      // 截图本地路径
  title: string;          // 简短标题
  summary: string;        // OCR 摘要
  category: Category;     // 分类
  highlightValue?: string; // 金额或时间数值
  createTime: string;     // 创建日期
}