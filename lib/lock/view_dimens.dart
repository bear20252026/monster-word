// 由 Claude 团队生成 | 移植自 v3.2 lock/ViewDimens.java
// 视图尺寸计算工具

class ViewDimens {
  static const double _exampleHeightPercent = 0.39;
  static const double _marginLeftPercent = 0.08;

  final int screenWidth;
  final int screenHeight;
  late final int exampleHeight;
  late final int marginLeft;

  ViewDimens(this.screenWidth, this.screenHeight) {
    exampleHeight = (screenHeight * _exampleHeightPercent + 0.5).toInt();
    marginLeft = (screenWidth * _marginLeftPercent + 0.5).toInt();
  }
}
