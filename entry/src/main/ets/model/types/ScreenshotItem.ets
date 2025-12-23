export interface ScreenshotItem {
  id: number;
  uri:Resource | string;
  thumbnail: Resource | string;
  importTime: number;
  status: string;
  fileName: string;
  category: string;
  createdTime: number;
}