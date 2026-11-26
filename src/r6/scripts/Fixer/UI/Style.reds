module Fixer

// The terminal in the game's own look: its colour styles, frame shapes and font, not colours of ours.
//  - Colours are bound from the game's style sheet (main_colors.inkstyle) by name, as the game's own script-built menu
//    does (browserModsMenu.script): a text or frame of ours then has exactly the game's colour, and follows it if a
//    patch or a UI mod changes the palette.
//  - Buttons and panels are the game's nine-slice shapes from atlas_shapes_sync.inkatlas (button_big2_bg/_fg for
//    buttons, cell_fg for panel frames).
//  - Text is Rajdhani, the game's UI font.
// Only the map's data marks keep fixed colours (FXColors): there the colour is the information.

// Roles, as the game's own script-built menu assigns them (browserModsMenu.script): body text and titles red, what is
// selected or yours blue, warnings yellow, dimmed grey.
public abstract class FXInk {
  public static func Title() -> CName = n"MainColors.Red";
  public static func Head() -> CName = n"MainColors.Blue";
  public static func Text() -> CName = n"MainColors.Red";
  public static func Dim() -> CName = n"MainColors.Grey";
  public static func Warn() -> CName = n"MainColors.Yellow";
  public static func Good() -> CName = n"MainColors.ActiveBlue";
  public static func Bad() -> CName = n"MainColors.ActiveRed";
  public static func Line() -> CName = n"MainColors.Red";
  public static func Panel() -> CName = n"MainColors.Fullscreen_PrimaryBackgroundDarkest";
}

// A button's two looks, the game's own (browserModsMenu.script, its dropdown and page buttons):
//  idle: red label on the dark red core, darker red frame;
//  hovered or selected: active blue label on the dark core, mild blue frame.
public abstract class FXButtonLook {
  public static func Label(on: Bool) -> CName = on ? n"MainColors.ActiveBlue" : n"MainColors.Red";
  public static func Core(on: Bool) -> CName = on ? n"MainColors.Fullscreen_PrimaryBackgroundDark" : n"MainColors.Fullscreen_RedDarkBackground";
  public static func Frame(on: Bool) -> CName = on ? n"MainColors.MildBlue" : n"MainColors.DarkerRed";
}

// Paint a button (built by FXTerminalPage.AddButtonH: children "bg", "frame", "label") idle or lit.
public func FXPaintButton(button: wref<inkWidget>, on: Bool) -> Void {
  let canvas = button as inkCompoundWidget;
  if !IsDefined(canvas) {
    return;
  }
  let core = canvas.GetWidget(n"bg");
  if IsDefined(core) {
    core.BindProperty(n"tintColor", FXButtonLook.Core(on));
  }
  let frame = canvas.GetWidget(n"frame");
  if IsDefined(frame) {
    frame.BindProperty(n"tintColor", FXButtonLook.Frame(on));
  }
  let label = canvas.GetWidget(n"label");
  if IsDefined(label) {
    label.BindProperty(n"tintColor", FXButtonLook.Label(on));
  }
}

public func FXStyleSheet() -> ResRef = r"base\\gameplay\\gui\\common\\main_colors.inkstyle";
public func FXShapesAtlas() -> ResRef = r"base\\gameplay\\gui\\common\\shapes\\atlas_shapes_sync.inkatlas";

// Bind a widget's colour to one of the game's colour styles.
public func FXTint(widget: ref<inkWidget>, role: CName) -> Void {
  widget.SetStyle(FXStyleSheet());
  widget.BindProperty(n"tintColor", role);
}

// One of the game's frame shapes, stretched to fill its parent.
public func FXFrame(name: CName, part: CName, role: CName, opacity: Float) -> ref<inkImage> {
  let image = new inkImage();
  image.SetName(name);
  image.SetAtlasResource(FXShapesAtlas());
  image.SetTexturePart(part);
  image.SetNineSliceScale(true);
  image.SetAnchor(inkEAnchor.Fill);
  image.SetOpacity(opacity);
  image.SetInteractive(false);
  FXTint(image, role);
  return image;
}

public func FXPageText(text: String, size: Int32, role: CName, style: CName) -> ref<inkText> {
  let t = new inkText();
  t.SetFontFamily("base\\gameplay\\gui\\fonts\\raj\\raj.inkfontfamily");
  t.SetFontStyle(style);
  t.SetFontSize(size);
  FXTint(t, role);
  t.SetText(text);
  return t;
}
