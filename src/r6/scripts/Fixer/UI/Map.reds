module Fixer

// The MAP and OPS tabs of the terminal.
//
// The map is drawn by us: the game's world map is a 3D fullscreen menu and can't be put inside a page. Everything on
// it sits at its real world position: fast-travel points (faint dots), turf blocks (squares), jobs (pins) and V.
// The view fits itself to whatever is on it, so no map coordinates are hardcoded. Before V runs City Center it shows
// City Center only; afterwards the whole city.
//
// Clicking a pin selects it (page-local, refreshed next frame). The card beside the map shows what the job needs and
// the odds for the crew V picks; SEND records a dispatch order for the tick.

public abstract class FXMapView {
  public static func MapW() -> Float = 860.0;
  public static func MapH() -> Float = 570.0;
  public static func CardW() -> Float = 470.0;

  // ================================================================ MAP tab

  public static func BuildMapTab(page: ref<FXTerminalPage>, content: ref<inkVerticalPanel>) -> Void {
    let row = new inkHorizontalPanel();
    row.Reparent(content);
    let left = new inkVerticalPanel();
    left.Reparent(row);
    let map = new inkCanvas();
    map.SetName(n"fx_map");
    map.SetSize(Vector2(FXMapView.MapW(), FXMapView.MapH()));
    map.Reparent(left);
    let unplaced = FXMapView.DrawMap(page, map);
    FXMapView.DrawLegend(page, left);
    // Jobs and blocks the map can't place (no position known yet) are still in play: list them, so every one can be
    // selected and worked even with no map data at all.
    let game = page.Game();
    let list = new inkHorizontalPanel();
    list.SetMargin(inkMargin(0.0, 6.0, 0.0, 0.0));
    list.Reparent(left);
    let shown = 0;
    let ops = FXOpsBook.Get(game);
    for id in unplaced {
      if shown < 4 && IsDefined(ops) {
        let job = ops.JobById(id);
        page.AddButtonH(list, FXJobTypeName(game, job.jobType), FXPageAction.SelectJob(), id, 205.0, 40.0, page.SelectedJob() == id);
        shown += 1;
      }
    }
    let career = FXCareerBook.Get(game);
    let war = FXWarBook.Get(game);
    let system = FXFixerSystem.Get(game);
    if IsDefined(career) && IsDefined(war) && IsDefined(system) && career.GetStage() >= FXStage.War() {
      let places = system.Places();
      let b = 0;
      while b < war.BlockCount() && shown < 4 {
        let place = FXFindPlace(places, war.BlockPlace(b));
        if !IsDefined(place) || !place.hasPos {
          page.AddButtonH(list, FXBlockName(game, b), FXPageAction.SelectBlock(), b, 205.0, 40.0, page.SelectedBlock() == b);
          shown += 1;
        }
        b += 1;
      }
    }
    let card = new inkVerticalPanel();
    card.SetName(n"fx_card");
    card.SetMargin(inkMargin(24.0, 0.0, 0.0, 0.0));
    card.Reparent(row);
    FXMapView.BuildCard(page, card);
  }

  // Draws the map; returns the ids of open or running jobs that have no position.
  public static func DrawMap(page: ref<FXTerminalPage>, map: ref<inkCanvas>) -> array<Int32> {
    let game = page.Game();
    let unplaced: array<Int32>;
    let career = FXCareerBook.Get(game);
    let ops = FXOpsBook.Get(game);
    let war = FXWarBook.Get(game);
    let system = FXFixerSystem.Get(game);
    let w = FXMapView.MapW();
    let h = FXMapView.MapH();

    let bg = new inkRectangle();
    bg.SetAnchor(inkEAnchor.Fill);
    bg.SetTintColor(FXColors.MapBg());
    bg.Reparent(map);
    if !IsDefined(career) || !IsDefined(ops) || !IsDefined(war) || !IsDefined(system) {
      return unplaced;
    }
    let cityOnly = career.GetStage() < FXStage.Fixer();
    let showBlocks = career.GetStage() >= FXStage.War() && war.BlockCount() > 0;
    let places = system.Places();

    // ---- What goes on the map, and the bounds it needs ----
    let minX = 1000000.0;
    let minY = 1000000.0;
    let maxX = -1000000.0;
    let maxY = -1000000.0;
    let points = 0;
    for p in places {
      if p.hasPos && (!cityOnly || p.cityCenter) {
        minX = MinF(minX, p.x); maxX = MaxF(maxX, p.x);
        minY = MinF(minY, p.y); maxY = MaxF(maxY, p.y);
        points += 1;
      }
    }
    let jobs: array<ref<FXJob>>;
    let n = ops.JobCount();
    let i = 0;
    while i < n {
      let j = ops.JobAt(i);
      if j.state == FXJobState.Open() || j.state == FXJobState.Running() {
        if j.hasPos {
          ArrayPush(jobs, j);
          minX = MinF(minX, j.x); maxX = MaxF(maxX, j.x);
          minY = MinF(minY, j.y); maxY = MaxF(maxY, j.y);
          points += 1;
        } else {
          ArrayPush(unplaced, j.id);
        }
      }
      i += 1;
    }
    if showBlocks {
      let b = 0;
      while b < war.BlockCount() {
        let place = FXFindPlace(places, war.BlockPlace(b));
        if IsDefined(place) && place.hasPos {
          minX = MinF(minX, place.x); maxX = MaxF(maxX, place.x);
          minY = MinF(minY, place.y); maxY = MaxF(maxY, place.y);
          points += 1;
        }
        b += 1;
      }
    }
    if points == 0 {
      let msg = FXPageText(FXText(game, "FX-Map-NoData"), 28, FXColors.Dim(), n"Regular");
      msg.SetWrapping(true, w - 60.0);
      msg.SetMargin(inkMargin(30.0, 30.0, 0.0, 0.0));
      msg.Reparent(map);
      return unplaced;
    }

    // ---- Projection: fit the bounds, keep the aspect, north up ----
    let dx = MaxF(maxX - minX, 400.0);
    let dy = MaxF(maxY - minY, 400.0);
    let cx = (minX + maxX) / 2.0;
    let cy = (minY + maxY) / 2.0;
    dx *= 1.12;
    dy *= 1.12;
    minX = cx - dx / 2.0;
    maxY = cy + dy / 2.0;
    let scale = MinF(w / dx, h / dy);
    let ox = (w - dx * scale) / 2.0;
    let oy = (h - dy * scale) / 2.0;

    // ---- Grid ----
    let g = 1;
    while g < 4 {
      let vline = new inkRectangle();
      vline.SetAnchor(inkEAnchor.TopLeft);
      vline.SetSize(Vector2(1.0, h));
      vline.SetMargin(inkMargin(w * Cast<Float>(g) / 4.0, 0.0, 0.0, 0.0));
      vline.SetTintColor(FXColors.Faint());
      vline.Reparent(map);
      let hline = new inkRectangle();
      hline.SetAnchor(inkEAnchor.TopLeft);
      hline.SetSize(Vector2(w, 1.0));
      hline.SetMargin(inkMargin(0.0, h * Cast<Float>(g) / 4.0, 0.0, 0.0));
      hline.SetTintColor(FXColors.Faint());
      hline.Reparent(map);
      g += 1;
    }

    // ---- Places and district names ----
    let districtNames: array<String>;
    let districtX: array<Float>;
    let districtY: array<Float>;
    let districtN: array<Int32>;
    for p in places {
      if p.hasPos && (!cityOnly || p.cityCenter) {
        let px = ox + (p.x - minX) * scale;
        let py = oy + (maxY - p.y) * scale;
        let size = p.subway ? 4.0 : 7.0;
        let dot = new inkRectangle();
        dot.SetAnchor(inkEAnchor.TopLeft);
        dot.SetSize(Vector2(size, size));
        dot.SetMargin(inkMargin(px - size / 2.0, py - size / 2.0, 0.0, 0.0));
        dot.SetTintColor(FXColors.Dim());
        dot.SetOpacity(0.7);
        dot.Reparent(map);
        if StrLen(p.districtName) > 0 {
          let k = ArrayFindFirst(districtNames, p.districtName);
          if k < 0 {
            ArrayPush(districtNames, p.districtName);
            ArrayPush(districtX, px);
            ArrayPush(districtY, py);
            ArrayPush(districtN, 1);
          } else {
            districtX[k] += px;
            districtY[k] += py;
            districtN[k] += 1;
          }
        }
      }
    }
    let d = 0;
    let nd = Min(ArraySize(districtNames), Min(ArraySize(districtX), Min(ArraySize(districtY), ArraySize(districtN))));
    while d < nd {
      let label = FXPageText(districtNames[d], 20, FXColors.Dim(), n"Medium");
      label.SetLetterCase(textLetterCase.UpperCase);
      label.SetAnchor(inkEAnchor.TopLeft);
      label.SetAnchorPoint(Vector2(0.5, 0.5));
      label.SetMargin(inkMargin(districtX[d] / Cast<Float>(districtN[d]), districtY[d] / Cast<Float>(districtN[d]) - 18.0, 0.0, 0.0));
      label.SetOpacity(0.8);
      label.Reparent(map);
      d += 1;
    }

    // ---- Turf blocks ----
    if showBlocks {
      let b = 0;
      while b < war.BlockCount() {
        let place = FXFindPlace(places, war.BlockPlace(b));
        if IsDefined(place) && place.hasPos {
          let px = ox + (place.x - minX) * scale;
          let py = oy + (maxY - place.y) * scale;
          if page.SelectedBlock() == b {
            FXMapView.Square(map, px, py, 40.0, FXColors.White(), 0.9);
          }
          let color = war.BlockHolder(b) == FXHolder.V() ? FXColors.Blue() : FXColors.Red();
          page.AddPin(map, FXPageAction.SelectBlock(), b, px, py, 32.0, color, 0.55);
        }
        b += 1;
      }
    }

    // ---- Jobs (running ones dimmed and smaller), the selected one on top ----
    let selected: ref<FXJob>;
    for j in jobs {
      if j.id == page.SelectedJob() {
        selected = j;
      } else {
        let px = ox + (j.x - minX) * scale;
        let py = oy + (maxY - j.y) * scale;
        let running = j.state == FXJobState.Running();
        page.AddPin(map, FXPageAction.SelectJob(), j.id, px, py, running ? 16.0 : 22.0, FXJobColor(j), running ? 0.45 : 1.0);
      }
    }
    if IsDefined(selected) {
      let px = ox + (selected.x - minX) * scale;
      let py = oy + (maxY - selected.y) * scale;
      FXMapView.Square(map, px, py, 34.0, FXColors.White(), 1.0);
      page.AddPin(map, FXPageAction.SelectJob(), selected.id, px, py, 26.0, FXJobColor(selected), 1.0);
    }

    // ---- V ----
    let player = FXPlayer(game);
    if IsDefined(player) {
      let pos = player.GetWorldPosition();
      let px = ox + (pos.X - minX) * scale;
      let py = oy + (maxY - pos.Y) * scale;
      if px >= 0.0 && px <= w && py >= 0.0 && py <= h {
        FXMapView.Square(map, px, py, 12.0, FXColors.Yellow(), 1.0);
        let you = FXPageText(FXText(game, "FX-Map-You"), 20, FXColors.Yellow(), n"Semi-Bold");
        you.SetAnchor(inkEAnchor.TopLeft);
        you.SetMargin(inkMargin(px + 10.0, py - 14.0, 0.0, 0.0));
        you.Reparent(map);
      }
    }
    return unplaced;
  }

  public static func Square(map: ref<inkCanvas>, x: Float, y: Float, size: Float, color: HDRColor, opacity: Float) -> Void {
    let r = new inkRectangle();
    r.SetAnchor(inkEAnchor.TopLeft);
    r.SetSize(Vector2(size, size));
    r.SetMargin(inkMargin(x - size / 2.0, y - size / 2.0, 0.0, 0.0));
    r.SetTintColor(color);
    r.SetOpacity(opacity);
    r.Reparent(map);
  }

  public static func DrawLegend(page: ref<FXTerminalPage>, parent: ref<inkVerticalPanel>) -> Void {
    let game = page.Game();
    let career = FXCareerBook.Get(game);
    let stage = IsDefined(career) ? career.GetStage() : 0;
    let row = new inkHorizontalPanel();
    row.SetMargin(inkMargin(0.0, 8.0, 0.0, 0.0));
    row.Reparent(parent);
    if stage == FXStage.Partner() {
      FXMapView.LegendItem(row, FXColors.Yellow(), FXText(game, "FX-Legend-Dino"));
    }
    if stage == FXStage.War() {
      FXMapView.LegendItem(row, FXColors.Red(), FXText(game, "FX-Legend-Strike"));
      FXMapView.LegendItem(row, FXColors.Blue(), FXText(game, "FX-Legend-Yours"));
    }
    if stage >= FXStage.Fixer() {
      FXMapView.LegendItem(row, FXColors.Blue(), FXText(game, "FX-Legend-Yours"));
      FXMapView.LegendItem(row, FXColors.Orange(), FXText(game, "FX-Legend-Gig"));
      FXMapView.LegendItem(row, FXColors.Sky(), FXText(game, "FX-Legend-NCPD"));
      FXMapView.LegendItem(row, FXColors.Magenta(), FXText(game, "FX-Legend-Psycho"));
      FXMapView.LegendItem(row, FXColors.Green(), FXText(game, "FX-Legend-Vehicle"));
      FXMapView.LegendItem(row, FXColors.Cyan(), FXText(game, "FX-Legend-Courier"));
    }
    if stage >= FXStage.War() {
      FXMapView.LegendItem(row, FXColors.Blue(), FXText(game, "FX-Legend-YourBlock"));
      FXMapView.LegendItem(row, FXColors.Red(), FXText(game, "FX-Legend-DinoBlock"));
    }
  }

  public static func LegendItem(row: ref<inkHorizontalPanel>, color: HDRColor, label: String) -> Void {
    let swatch = new inkRectangle();
    swatch.SetSize(Vector2(14.0, 14.0));
    swatch.SetTintColor(color);
    swatch.SetMargin(inkMargin(0.0, 8.0, 6.0, 0.0));
    swatch.Reparent(row);
    let text = FXPageText(label, 20, FXColors.Dim(), n"Regular");
    text.SetMargin(inkMargin(0.0, 0.0, 16.0, 0.0));
    text.Reparent(row);
  }

  // ================================================================ the card beside the map

  public static func BuildCard(page: ref<FXTerminalPage>, card: ref<inkVerticalPanel>) -> Void {
    let game = page.Game();
    let ops = FXOpsBook.Get(game);
    if !IsDefined(ops) {
      return;
    }
    if page.SelectedJob() != 0 {
      let job = ops.JobById(page.SelectedJob());
      if IsDefined(job) && (job.state == FXJobState.Open() || job.state == FXJobState.Running()) {
        FXMapView.JobCard(page, card, job);
        return;
      }
    }
    if page.SelectedBlock() >= 0 {
      FXMapView.BlockCard(page, card, page.SelectedBlock());
      return;
    }
    FXMapView.HelpCard(page, card);
  }

  public static func JobCard(page: ref<FXTerminalPage>, card: ref<inkVerticalPanel>, job: ref<FXJob>) -> Void {
    let game = page.Game();
    let crew = FXCrewBook.Get(game);
    let ops = FXOpsBook.Get(game);
    let war = FXWarBook.Get(game);
    let cw = FXMapView.CardW();

    page.AddLineW(card, FXJobTitle(game, job), 32, FXColors.Blue(), cw);
    let area = FXPlaceDistrictName(game, job.place);
    let kindLine = FXJobKindLabel(game, job);
    if StrLen(area) > 0 {
      kindLine = s"\(kindLine)  //  \(area)";
    }
    page.AddLineW(card, kindLine, 24, FXColors.Dim(), cw);
    page.AddLineW(card, FXTextF(game, "FX-Card-Facts", [ToString(job.difficulty), ToString(job.hours), ToString(job.need)]), 28, FXColors.Text(), cw);
    let payLine = FXTextF(game, "FX-Card-Pay", [FXMoneyText(job.pay)]);
    let dinoCut = job.kind == FXJobKind.Dino() && IsDefined(war) ? war.DinoCut() : job.dinoCut;
    if dinoCut > 0 {
      payLine = s"\(payLine)  //  \(FXTextF(game, "FX-Card-DinoTakes", [ToString(dinoCut)]))";
    }
    page.AddLineW(card, payLine, 28, FXColors.Text(), cw);
    page.AddLineW(card, FXTextF(game, "FX-Card-Roles", [FXRoleName(game, FXJobRoleA(job.jobType)), FXRoleName(game, FXJobRoleB(job.jobType))]), 24, FXColors.Dim(), cw);
    let heatLine = FXTextF(game, "FX-Card-Heat", [ToString(FXJobHeat(job.jobType, job.difficulty))]);
    if job.IsArasaka() {
      heatLine = s"\(heatLine)  //  \(FXText(game, "FX-Card-Arasaka"))";
    }
    page.AddLineW(card, heatLine, 24, job.IsArasaka() ? FXColors.Red() : FXColors.Dim(), cw);

    if job.state == FXJobState.Running() {
      let members = ops.MembersOf(job.id);
      let names = "";
      for id in members {
        let p = FXFindPerson(game, id);
        names = StrLen(names) == 0 ? FXPersonHandle(p) : s"\(names), \(FXPersonHandle(p))";
      }
      let hoursLeft = Max(0, CeilF((job.due - FXNow(game)) / 3600.0));
      page.AddLineW(card, FXTextF(game, "FX-Card-Running", [names, ToString(hoursLeft)]), 28, FXColors.Yellow(), cw);
      page.AddLineW(card, FXTextF(game, "FX-Card-Odds", [ToString(RoundF(FXSuccessForJob(game, job, members) * 100.0))]), 28, FXColors.Text(), cw);
    } else {
      page.AddLineW(card, FXText(game, "FX-Card-Pick"), 24, FXColors.Yellow(), cw);
      let shown = 0;
      let free = 0;
      let n = crew.RosterSize();
      let i = 0;
      while i < n {
        if crew.IsAvailableAt(i) {
          free += 1;
          if shown < 6 {
            let p = crew.MemberAt(i);
            let picked = page.IsPicked(p.id);
            let label = s"\(picked ? "[X] " : "[  ] ")\(FXPersonHandle(p))  //  \(FXRoleName(game, p.role))  //  \(p.skill)";
            page.AddButtonH(card, label, FXPageAction.ToggleCrew(), p.id, cw, 40.0, picked);
            shown += 1;
          }
        }
        i += 1;
      }
      if free == 0 {
        page.AddLineW(card, FXText(game, "FX-Card-NobodyFree"), 26, FXColors.Red(), cw);
      }
      // Crew cut.
      let cutRow = new inkHorizontalPanel();
      cutRow.SetMargin(inkMargin(0.0, 6.0, 0.0, 0.0));
      cutRow.Reparent(card);
      page.AddButtonH(cutRow, "-", FXPageAction.CutDown(), 0, 56.0, 40.0, false);
      let cutText = FXPageText(FXTextF(game, "FX-Card-Cut", [ToString(page.Cut())]), 26, FXColors.Text(), n"Medium");
      cutText.SetMargin(inkMargin(0.0, 6.0, 14.0, 0.0));
      cutText.Reparent(cutRow);
      page.AddButtonH(cutRow, "+", FXPageAction.CutUp(), 0, 56.0, 40.0, false);

      // The odds and V's take for exactly this pick and cut. Only picked members who are still free count (someone
      // picked a moment ago may have been hurt or walked out since); the dispatch applies the same filter.
      let all = page.Picked();
      let picked: array<Int32>;
      for id in all {
        let mi = crew.IndexOfMember(id);
        if mi >= 0 && crew.IsAvailableAt(mi) {
          ArrayPush(picked, id);
        }
      }
      let count = ArraySize(picked);
      let chance = FXSuccessForJob(game, job, picked);
      let pct = RoundF(chance * 100.0);
      let preview = ops.JobById(job.id);
      preview.cut = page.Cut();
      preview.dinoCut = dinoCut;
      if count >= job.need {
        let color = pct >= 70 ? FXColors.Green() : (pct >= 40 ? FXColors.Yellow() : FXColors.Red());
        page.AddLineW(card, FXTextF(game, "FX-Card-Success", [ToString(pct)]), 36, color, cw);
        page.AddLineW(card, FXTextF(game, "FX-Card-Take", [FXMoneyText(FXVTake(preview, FXOutcome.Success()))]), 24, FXColors.Text(), cw);
      } else {
        page.AddLineW(card, FXTextF(game, "FX-Card-PickMore", [ToString(job.need - count)]), 28, FXColors.Yellow(), cw);
      }
      let actions = new inkHorizontalPanel();
      actions.SetMargin(inkMargin(0.0, 6.0, 0.0, 0.0));
      actions.Reparent(card);
      if count >= job.need {
        page.AddButtonH(actions, FXText(game, "FX-Card-Send"), FXPageAction.Send(), job.id, 220.0, 52.0, true);
      }
      if job.hasPos {
        page.AddButtonH(actions, FXText(game, "FX-Card-ShowOnMap"), FXAction.MarkJob(), job.id, 220.0, 52.0, false);
      }
      return;
    }
    if job.hasPos {
      page.AddButtonH(card, FXText(game, "FX-Card-ShowOnMap"), FXAction.MarkJob(), job.id, 220.0, 52.0, false);
    }
  }

  public static func BlockCard(page: ref<FXTerminalPage>, card: ref<inkVerticalPanel>, b: Int32) -> Void {
    let game = page.Game();
    let war = FXWarBook.Get(game);
    let cw = FXMapView.CardW();
    if !IsDefined(war) || b < 0 || b >= war.BlockCount() {
      FXMapView.HelpCard(page, card);
      return;
    }
    page.AddLineW(card, FXBlockName(game, b), 32, FXColors.Blue(), cw);
    page.AddLineW(card, FXPlaceDistrictName(game, war.BlockPlace(b)), 24, FXColors.Dim(), cw);
    if war.BlockHolder(b) == FXHolder.V() {
      page.AddLineW(card, FXText(game, "FX-Block-Yours"), 28, FXColors.Blue(), cw);
      let guard = war.BlockGuard(b);
      let guardName = guard != 0 ? FXPersonName(FXFindPerson(game, guard)) : FXText(game, "FX-Block-NoGuard");
      page.AddLineW(card, FXTextF(game, "FX-Block-Guard", [guardName]), 28, FXColors.Text(), cw);
      page.AddLineW(card, FXText(game, "FX-Block-GuardHelp"), 24, FXColors.Dim(), cw);
      let row = new inkHorizontalPanel();
      row.Reparent(card);
      page.AddButtonH(row, FXText(game, "FX-Block-NextGuard"), FXPageAction.GuardNext(), b, 220.0, 52.0, false);
      if guard != 0 {
        page.AddButtonH(row, FXText(game, "FX-Block-Unguard"), FXPageAction.Unguard(), b, 220.0, 52.0, false);
      }
    } else {
      page.AddLineW(card, FXText(game, "FX-Block-Dinos"), 28, FXColors.Red(), cw);
      page.AddLineW(card, FXText(game, "FX-Block-StrikeHelp"), 24, FXColors.Dim(), cw);
    }
  }

  public static func HelpCard(page: ref<FXTerminalPage>, card: ref<inkVerticalPanel>) -> Void {
    let game = page.Game();
    let career = FXCareerBook.Get(game);
    let ops = FXOpsBook.Get(game);
    let cw = FXMapView.CardW();
    let stage = IsDefined(career) ? career.GetStage() : 0;
    let key = "FX-Help-Partner";
    if stage == FXStage.War() {
      key = "FX-Help-War";
    }
    if stage >= FXStage.Fixer() {
      key = "FX-Help-Fixer";
    }
    page.AddLineW(card, FXText(game, key), 28, FXColors.Text(), cw);
    if IsDefined(ops) {
      page.AddLineW(card, FXTextF(game, "FX-Help-Counts", [ToString(ops.CountByState(FXJobState.Open())), ToString(ops.CountByState(FXJobState.Running()))]), 26, FXColors.Dim(), cw);
    }
    if IsDefined(career) {
      page.AddLineW(card, FXTextF(game, "FX-UI-Next", [FXNextStepText(game, career)]), 26, FXColors.Yellow(), cw);
    }
  }

  // ================================================================ OPS tab

  public static func BuildOpsTab(page: ref<FXTerminalPage>, content: ref<inkVerticalPanel>) -> Void {
    let game = page.Game();
    let ops = FXOpsBook.Get(game);
    let career = FXCareerBook.Get(game);
    if !IsDefined(ops) || !IsDefined(career) {
      return;
    }
    FXMapView.HeatBar(page, content, FXText(game, "FX-Ops-HeatNcpd"), ops.HeatNcpd());
    FXMapView.HeatBar(page, content, FXText(game, "FX-Ops-HeatArasaka"), ops.HeatArasaka());
    page.AddLine(content, FXTextF(game, "FX-UI-Next", [FXNextStepText(game, career)]), 28, FXColors.Yellow());
    page.AddLine(content, FXTextF(game, "FX-UI-Earned", [FXMoneyText(ops.TotalEarned())]), 28, FXColors.Text());

    let row = new inkHorizontalPanel();
    row.SetMargin(inkMargin(0.0, 8.0, 0.0, 0.0));
    row.Reparent(content);
    let colA = new inkVerticalPanel();
    colA.Reparent(row);
    let colB = new inkVerticalPanel();
    colB.SetMargin(inkMargin(40.0, 0.0, 0.0, 0.0));
    colB.Reparent(row);

    // Under way and recent results.
    page.AddLineW(colA, FXText(game, "FX-Ops-Running"), 28, FXColors.Blue(), 680.0);
    let now = FXNow(game);
    let shown = 0;
    let n = ops.JobCount();
    let i = 0;
    while i < n {
      let j = ops.JobAt(i);
      if j.state == FXJobState.Running() && shown < 5 {
        let hoursLeft = Max(0, CeilF((j.due - now) / 3600.0));
        page.AddLineW(colA, FXTextF(game, "FX-Ops-RunningLine", [FXJobTitle(game, j), ToString(hoursLeft)]), 24, FXColors.Text(), 680.0);
        shown += 1;
      }
      i += 1;
    }
    if shown == 0 {
      page.AddLineW(colA, FXText(game, "FX-Ops-None"), 24, FXColors.Dim(), 680.0);
    }
    page.AddLineW(colA, FXText(game, "FX-Ops-Results"), 28, FXColors.Blue(), 680.0);
    shown = 0;
    i = n - 1;
    while i >= 0 && shown < 6 {
      let j = ops.JobAt(i);
      if j.state == FXJobState.Done() {
        let color = j.outcome == FXOutcome.Success() ? FXColors.Green() : (j.outcome == FXOutcome.Partial() ? FXColors.Yellow() : FXColors.Red());
        page.AddLineW(colA, FXTextF(game, "FX-Ops-ResultLine", [FXJobTitle(game, j), FXOutcomeName(game, j.outcome), FXMoneyText(FXVTake(j, j.outcome))]), 24, color, 680.0);
        shown += 1;
      }
      i -= 1;
    }
    if shown == 0 {
      page.AddLineW(colA, FXText(game, "FX-Ops-None"), 24, FXColors.Dim(), 680.0);
    }

    // The ledger, newest first.
    page.AddLineW(colB, FXText(game, "FX-Ops-Ledger"), 28, FXColors.Blue(), 600.0);
    let ln = ops.LedgerCount();
    let k = ln - 1;
    shown = 0;
    while k >= 0 && shown < 8 {
      let kindKey = ops.LedgerKindAt(k) == FXLedgerKind.Turf() ? "FX-Ops-LedgerTurf" : "FX-Ops-LedgerJob";
      page.AddLineW(colB, FXTextF(game, "FX-Ops-LedgerLine", [ToString(ops.LedgerDayAt(k)), FXText(game, kindKey), FXMoneyText(ops.LedgerAmountAt(k))]), 24, FXColors.Text(), 600.0);
      shown += 1;
      k -= 1;
    }
    if shown == 0 {
      page.AddLineW(colB, FXText(game, "FX-Ops-None"), 24, FXColors.Dim(), 600.0);
    }
  }

  public static func HeatBar(page: ref<FXTerminalPage>, parent: ref<inkVerticalPanel>, label: String, value: Int32) -> Void {
    let row = new inkHorizontalPanel();
    row.SetMargin(inkMargin(0.0, 0.0, 0.0, 8.0));
    row.Reparent(parent);
    let text = FXPageText(s"\(label)  \(value)/100", 26, FXColors.Text(), n"Medium");
    text.SetSize(Vector2(360.0, 34.0));
    text.Reparent(row);
    let bar = new inkCanvas();
    bar.SetSize(Vector2(600.0, 18.0));
    bar.SetMargin(inkMargin(10.0, 8.0, 0.0, 0.0));
    bar.Reparent(row);
    let back = new inkRectangle();
    back.SetAnchor(inkEAnchor.Fill);
    back.SetTintColor(FXColors.Faint());
    back.Reparent(bar);
    let fill = new inkRectangle();
    fill.SetAnchor(inkEAnchor.TopLeft);
    fill.SetSize(Vector2(600.0 * Cast<Float>(Clamp(value, 0, 100)) / 100.0, 18.0));
    fill.SetTintColor(value >= 60 ? FXColors.Red() : (value >= 40 ? FXColors.Yellow() : FXColors.Green()));
    fill.Reparent(bar);
  }
}

public func FXJobColor(job: ref<FXJob>) -> HDRColor {
  switch job.kind {
    case FXJobKind.Dino(): return FXColors.Yellow();
    case FXJobKind.Strike(): return FXColors.Red();
    case FXJobKind.Street(): return FXColors.Blue();
    default:
      switch job.jobType {
        case FXJobType.Assault(): return FXColors.Sky();
        case FXJobType.PsychoHunt(): return FXColors.Magenta();
        case FXJobType.VehicleJob(): return FXColors.Green();
        case FXJobType.Courier(): return FXColors.Cyan();
        default: return FXColors.Orange();
      }
  }
}

public func FXJobKindLabel(game: GameInstance, job: ref<FXJob>) -> String {
  if job.kind == FXJobKind.Vanilla() {
    let site = "FX-Site-Gig";
    switch job.jobType {
      case FXJobType.Assault(): site = "FX-Site-NCPD"; break;
      case FXJobType.PsychoHunt(): site = "FX-Site-Psycho"; break;
      case FXJobType.VehicleJob(): site = "FX-Site-Vehicle"; break;
      case FXJobType.Courier(): site = "FX-Site-Courier"; break;
      default: break;
    }
    return FXTextF(game, "FX-Kind-2", [FXText(game, site)]);
  }
  return FXText(game, s"FX-Kind-\(Clamp(job.kind, 0, 3))");
}
