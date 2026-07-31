enum FilterType {
  all('전체'),
  work('인건비'),
  notPay('미지급'),
  material('자재비'),
  catetory1('목재'),
  catetory2('금속'),
  catetory3('전기'),
  catetory4('조명'),
  catetory5('청소'),
  catetory6('필름'),
  catetory7('조경'),
  catetory8('철물'),
  catetory9('페인트'),
  catetory10('설비'),
  catetory11('타일'),
  catetory12('유리'),
  catetory13('유류비'),
  catetory14('숙반'),
  catetory15('식대'),
  catetory16('개인경비'),
  catetory17('소방'),
  catetory18('사인물'),
  catetory19('공조'),
  catetory20('철거'),
  catetory21('기타주문제작'),
  catetory22('기타경비'),
  ;

  const FilterType(this.category);
  final String category;
}

enum TaxState { taxOn, taxOff }

enum WCompleteState { incomplete, whole }

enum PlaceState { complete, incomplete }

enum TotalSegment { place, duration }

enum DayTpye { range, whole, month, year }

enum CompleteState { incomplete, whole }
