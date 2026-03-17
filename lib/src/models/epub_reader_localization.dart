/// Localization strings for the EPUB reader UI.
///
/// All fields default to Korean for backwards compatibility.
/// Use [EpubReaderLocalization.english] for English, or provide
/// custom translations via the constructor.
class EpubReaderLocalization {
  /// Theme label.
  final String theme;

  /// Sample character displayed in theme color swatches.
  final String themeSampleChar;

  /// Font label.
  final String font;

  /// Font size label.
  final String fontSize;

  /// Line spacing label.
  final String lineSpacing;

  /// Margin label.
  final String margin;

  /// View mode label.
  final String viewMode;

  /// Page mode label.
  final String pageMode;

  /// Scroll mode label.
  final String scrollMode;

  /// Reset settings button label.
  final String resetSettings;

  /// Serif font display name.
  final String fontSerif;

  /// Sans-serif font display name.
  final String fontSansSerif;

  /// Noto Sans font display name.
  final String fontNotoSans;

  /// Load failed title shown in error view.
  final String loadFailed;

  /// Unknown error fallback message.
  final String unknownError;

  /// Message shown when content cannot be loaded.
  final String cannotLoadContent;

  /// Message suggesting to check the file format.
  final String checkFileFormat;

  /// Creates localization with Korean defaults.
  const EpubReaderLocalization({
    this.theme = '테마',
    this.themeSampleChar = '가',
    this.font = '글꼴',
    this.fontSize = '글자 크기',
    this.lineSpacing = '줄 간격',
    this.margin = '여백',
    this.viewMode = '보기 모드',
    this.pageMode = '페이지',
    this.scrollMode = '스크롤',
    this.resetSettings = '보기 설정 초기화',
    this.fontSerif = '명조',
    this.fontSansSerif = '고딕',
    this.fontNotoSans = 'Sans',
    this.loadFailed = '로드 실패',
    this.unknownError = '알 수 없는 오류',
    this.cannotLoadContent = '콘텐츠를 불러올 수 없습니다',
    this.checkFileFormat = 'EPUB 파일 형식을 확인해주세요',
  });

  /// Korean localization (same as default).
  static const korean = EpubReaderLocalization();

  /// English localization.
  static const english = EpubReaderLocalization(
    theme: 'Theme',
    themeSampleChar: 'A',
    font: 'Font',
    fontSize: 'Font Size',
    lineSpacing: 'Line Spacing',
    margin: 'Margin',
    viewMode: 'View Mode',
    pageMode: 'Page',
    scrollMode: 'Scroll',
    resetSettings: 'Reset Settings',
    fontSerif: 'Serif',
    fontSansSerif: 'Sans-serif',
    fontNotoSans: 'Sans',
    loadFailed: 'Load Failed',
    unknownError: 'Unknown error',
    cannotLoadContent: 'Cannot load content',
    checkFileFormat: 'Please check the EPUB file format',
  );

  /// Chinese (Simplified) localization.
  static const chinese = EpubReaderLocalization(
    theme: '主题',
    themeSampleChar: '字',
    font: '字体',
    fontSize: '字号',
    lineSpacing: '行距',
    margin: '边距',
    viewMode: '阅读模式',
    pageMode: '翻页',
    scrollMode: '滚动',
    resetSettings: '重置设置',
    fontSerif: '宋体',
    fontSansSerif: '黑体',
    fontNotoSans: 'Sans',
    loadFailed: '加载失败',
    unknownError: '未知错误',
    cannotLoadContent: '无法加载内容',
    checkFileFormat: '请检查EPUB文件格式',
  );

  /// Japanese localization.
  static const japanese = EpubReaderLocalization(
    theme: 'テーマ',
    themeSampleChar: 'あ',
    font: 'フォント',
    fontSize: '文字サイズ',
    lineSpacing: '行間',
    margin: '余白',
    viewMode: '表示モード',
    pageMode: 'ページ',
    scrollMode: 'スクロール',
    resetSettings: '設定をリセット',
    fontSerif: '明朝',
    fontSansSerif: 'ゴシック',
    fontNotoSans: 'Sans',
    loadFailed: '読み込み失敗',
    unknownError: '不明なエラー',
    cannotLoadContent: 'コンテンツを読み込めません',
    checkFileFormat: 'EPUBファイル形式を確認してください',
  );

  /// Hindi localization.
  static const hindi = EpubReaderLocalization(
    theme: 'थीम',
    themeSampleChar: 'अ',
    font: 'फ़ॉन्ट',
    fontSize: 'फ़ॉन्ट आकार',
    lineSpacing: 'पंक्ति अंतराल',
    margin: 'हाशिया',
    viewMode: 'व्यू मोड',
    pageMode: 'पृष्ठ',
    scrollMode: 'स्क्रॉल',
    resetSettings: 'सेटिंग रीसेट करें',
    fontSerif: 'सेरिफ़',
    fontSansSerif: 'सैन्स-सेरिफ़',
    fontNotoSans: 'Sans',
    loadFailed: 'लोड विफल',
    unknownError: 'अज्ञात त्रुटि',
    cannotLoadContent: 'सामग्री लोड नहीं हो सकती',
    checkFileFormat: 'कृपया EPUB फ़ाइल प्रारूप जाँचें',
  );

  /// Spanish localization.
  static const spanish = EpubReaderLocalization(
    theme: 'Tema',
    themeSampleChar: 'A',
    font: 'Fuente',
    fontSize: 'Tamaño de fuente',
    lineSpacing: 'Interlineado',
    margin: 'Margen',
    viewMode: 'Modo de vista',
    pageMode: 'Página',
    scrollMode: 'Desplazamiento',
    resetSettings: 'Restablecer ajustes',
    fontSerif: 'Serif',
    fontSansSerif: 'Sans-serif',
    fontNotoSans: 'Sans',
    loadFailed: 'Error de carga',
    unknownError: 'Error desconocido',
    cannotLoadContent: 'No se puede cargar el contenido',
    checkFileFormat: 'Por favor, compruebe el formato del archivo EPUB',
  );

  /// Arabic localization.
  static const arabic = EpubReaderLocalization(
    theme: 'السمة',
    themeSampleChar: 'ع',
    font: 'الخط',
    fontSize: 'حجم الخط',
    lineSpacing: 'تباعد الأسطر',
    margin: 'الهامش',
    viewMode: 'وضع العرض',
    pageMode: 'صفحة',
    scrollMode: 'تمرير',
    resetSettings: 'إعادة تعيين الإعدادات',
    fontSerif: 'مذيّل',
    fontSansSerif: 'بلا ذيل',
    fontNotoSans: 'Sans',
    loadFailed: 'فشل التحميل',
    unknownError: 'خطأ غير معروف',
    cannotLoadContent: 'تعذّر تحميل المحتوى',
    checkFileFormat: 'يرجى التحقق من تنسيق ملف EPUB',
  );

  /// French localization.
  static const french = EpubReaderLocalization(
    theme: 'Thème',
    themeSampleChar: 'A',
    font: 'Police',
    fontSize: 'Taille de police',
    lineSpacing: 'Interligne',
    margin: 'Marge',
    viewMode: 'Mode d\'affichage',
    pageMode: 'Page',
    scrollMode: 'Défilement',
    resetSettings: 'Réinitialiser les paramètres',
    fontSerif: 'Serif',
    fontSansSerif: 'Sans-serif',
    fontNotoSans: 'Sans',
    loadFailed: 'Échec du chargement',
    unknownError: 'Erreur inconnue',
    cannotLoadContent: 'Impossible de charger le contenu',
    checkFileFormat: 'Veuillez vérifier le format du fichier EPUB',
  );

  /// Portuguese localization.
  static const portuguese = EpubReaderLocalization(
    theme: 'Tema',
    themeSampleChar: 'A',
    font: 'Fonte',
    fontSize: 'Tamanho da fonte',
    lineSpacing: 'Espaçamento entre linhas',
    margin: 'Margem',
    viewMode: 'Modo de visualização',
    pageMode: 'Página',
    scrollMode: 'Rolagem',
    resetSettings: 'Redefinir configurações',
    fontSerif: 'Serifada',
    fontSansSerif: 'Sem serifa',
    fontNotoSans: 'Sans',
    loadFailed: 'Falha ao carregar',
    unknownError: 'Erro desconhecido',
    cannotLoadContent: 'Não foi possível carregar o conteúdo',
    checkFileFormat: 'Por favor, verifique o formato do arquivo EPUB',
  );

  /// Russian localization.
  static const russian = EpubReaderLocalization(
    theme: 'Тема',
    themeSampleChar: 'А',
    font: 'Шрифт',
    fontSize: 'Размер шрифта',
    lineSpacing: 'Межстрочный интервал',
    margin: 'Поля',
    viewMode: 'Режим просмотра',
    pageMode: 'Страница',
    scrollMode: 'Прокрутка',
    resetSettings: 'Сбросить настройки',
    fontSerif: 'С засечками',
    fontSansSerif: 'Без засечек',
    fontNotoSans: 'Sans',
    loadFailed: 'Ошибка загрузки',
    unknownError: 'Неизвестная ошибка',
    cannotLoadContent: 'Не удалось загрузить содержимое',
    checkFileFormat: 'Пожалуйста, проверьте формат файла EPUB',
  );

  /// German localization.
  static const german = EpubReaderLocalization(
    theme: 'Design',
    themeSampleChar: 'A',
    font: 'Schriftart',
    fontSize: 'Schriftgröße',
    lineSpacing: 'Zeilenabstand',
    margin: 'Rand',
    viewMode: 'Ansichtsmodus',
    pageMode: 'Seite',
    scrollMode: 'Scrollen',
    resetSettings: 'Einstellungen zurücksetzen',
    fontSerif: 'Serif',
    fontSansSerif: 'Sans-serif',
    fontNotoSans: 'Sans',
    loadFailed: 'Laden fehlgeschlagen',
    unknownError: 'Unbekannter Fehler',
    cannotLoadContent: 'Inhalt konnte nicht geladen werden',
    checkFileFormat: 'Bitte überprüfen Sie das EPUB-Dateiformat',
  );
}
