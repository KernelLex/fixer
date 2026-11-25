module Fixer

// Every message V has received, newest last. A message is stored as numbers only: who sent it, which kind of message,
// which variant of the wording, and up to two references (a lead id, a crew id, a gig hash). The text is built when
// it's shown (Messages/Lines.reds), so the save holds no strings and a translation applies to old messages too.

public abstract class FXSender {
  public static func Person() -> Int32 = 0;   // a lead or crew member: name from ref A (lead id) or ref B (crew id)
  public static func Dino() -> Int32 = 1;
  public static func Net() -> Int32 = 2;      // the fixer network: system notices
}

// Message kinds. Saved: never renumber, only append.
public abstract class FXMsgKind {
  public static func LeadOffer() -> Int32 = 0;        // A = lead id, B = gig hash
  public static func LeadHired() -> Int32 = 1;        // A = lead id
  public static func LeadDeclined() -> Int32 = 2;     // A = lead id
  public static func LeadExpired() -> Int32 = 3;      // A = lead id
  public static func StageRecruiter() -> Int32 = 4;
  public static func StageCandidate() -> Int32 = 5;
  public static func RosterFull() -> Int32 = 6;       // A = lead id
  public static func Welcome() -> Int32 = 7;
  // Phase 2: Dino and the job loop
  public static func DinoOffer() -> Int32 = 8;
  public static func DinoOfferAccepted() -> Int32 = 9;
  public static func DinoOfferDeclined() -> Int32 = 10;
  public static func JobSuccess() -> Int32 = 11;      // A = reporting member, B = job id
  public static func JobPartial() -> Int32 = 12;      // A = reporting member, B = job id
  public static func JobFail() -> Int32 = 13;         // A = reporting member, B = job id
  public static func JobDisaster() -> Int32 = 14;     // A = reporting member, B = job id
  public static func MemberRecovered() -> Int32 = 15; // A = member
  public static func MemberReleased() -> Int32 = 16;  // A = member
  public static func MemberDeserted() -> Int32 = 17;  // A = member
  public static func MemberBetrayed() -> Int32 = 18;  // A = member
  public static func MemberLevelUp() -> Int32 = 19;   // A = member
  // Phase 3: the war
  public static func DinoRaise() -> Int32 = 20;       // A = the cut Dino wants
  public static func DinoWar() -> Int32 = 21;
  public static func WarBlockTaken() -> Int32 = 22;   // B = block index + 1
  public static func WarBlockLost() -> Int32 = 23;    // B = block index + 1
  public static func WarAmbush() -> Int32 = 24;       // A = member, B = FXCasualty
  public static func WarBlockDefended() -> Int32 = 25; // A = guard, B = block index + 1
  public static func WarPoached() -> Int32 = 26;      // A = member
  public static func WarTipoff() -> Int32 = 27;
  public static func DinoDefeated() -> Int32 = 28;
  // Phase 4: the city board
  public static func CityBoardOpen() -> Int32 = 29;
  public static func JobLost() -> Int32 = 30;         // B = job id: nobody left to report
}

public abstract class FXMsgFlag {
  public static func Read() -> Int32 = 1;
}

public class FXInboxBook extends ScriptableSystem {
  private persistent let m_saveVersion: Int32;
  private persistent let m_nextId: Int32;

  private persistent let m_id: array<Int32>;
  private persistent let m_sender: array<Int32>;
  private persistent let m_kind: array<Int32>;
  private persistent let m_variant: array<Int32>;
  private persistent let m_refA: array<Int32>;
  private persistent let m_refB: array<Int32>;
  private persistent let m_flags: array<Int32>;
  private persistent let m_time: array<Float>;

  public static func Get(game: GameInstance) -> ref<FXInboxBook> {
    let container = GameInstance.GetScriptableSystemsContainer(game);
    if !IsDefined(container) {
      return null;
    }
    return container.Get(n"Fixer.FXInboxBook") as FXInboxBook;
  }

  public static func Cap() -> Int32 = 80;

  public func Migrate() -> Void {
    if this.m_saveVersion == FXSaveVersion() {
      return;
    }
    this.Trim();
    if this.m_nextId < 1 {
      this.m_nextId = 1;
    }
    this.m_saveVersion = FXSaveVersion();
  }

  public func Count() -> Int32 {
    return Min(ArraySize(this.m_id), ArraySize(this.m_time));
  }

  public func Add(sender: Int32, kind: Int32, variant: Int32, refA: Int32, refB: Int32, time: Float) -> Int32 {
    if this.m_nextId < 1 {
      this.m_nextId = 1;
    }
    let id = this.m_nextId;
    this.m_nextId += 1;
    ArrayPush(this.m_id, id);
    ArrayPush(this.m_sender, sender);
    ArrayPush(this.m_kind, kind);
    ArrayPush(this.m_variant, variant);
    ArrayPush(this.m_refA, refA);
    ArrayPush(this.m_refB, refB);
    ArrayPush(this.m_flags, 0);
    ArrayPush(this.m_time, time);
    while this.Count() > FXInboxBook.Cap() {
      this.RemoveAt(0);
    }
    return id;
  }

  public func IndexOf(id: Int32) -> Int32 {
    return ArrayFindFirst(this.m_id, id);
  }

  public func IdAt(i: Int32) -> Int32 = this.Valid(i) ? this.m_id[i] : 0;
  public func SenderAt(i: Int32) -> Int32 = this.Valid(i) ? this.m_sender[i] : 0;
  public func KindAt(i: Int32) -> Int32 = this.Valid(i) ? this.m_kind[i] : 0;
  public func VariantAt(i: Int32) -> Int32 = this.Valid(i) ? this.m_variant[i] : 0;
  public func RefAAt(i: Int32) -> Int32 = this.Valid(i) ? this.m_refA[i] : 0;
  public func RefBAt(i: Int32) -> Int32 = this.Valid(i) ? this.m_refB[i] : 0;
  public func FlagsAt(i: Int32) -> Int32 = this.Valid(i) ? this.m_flags[i] : 0;
  public func TimeAt(i: Int32) -> Float = this.Valid(i) ? this.m_time[i] : 0.0;

  // The newest message of a kind, or -1. Only the newest offer carries answer buttons.
  public func LastIndexOfKind(kind: Int32) -> Int32 {
    let i = this.Count() - 1;
    while i >= 0 {
      if this.m_kind[i] == kind {
        return i;
      }
      i -= 1;
    }
    return -1;
  }

  public func UnreadCount() -> Int32 {
    let n = this.Count();
    let count = 0;
    let i = 0;
    while i < n {
      if (this.m_flags[i] & FXMsgFlag.Read()) == 0 {
        count += 1;
      }
      i += 1;
    }
    return count;
  }

  public func MarkAllRead() -> Void {
    let n = this.Count();
    let i = 0;
    while i < n {
      this.m_flags[i] = this.m_flags[i] | FXMsgFlag.Read();
      i += 1;
    }
  }

  private func Valid(i: Int32) -> Bool {
    return i >= 0 && i < this.Count();
  }

  private func RemoveAt(i: Int32) -> Void {
    ArrayErase(this.m_id, i);
    ArrayErase(this.m_sender, i);
    ArrayErase(this.m_kind, i);
    ArrayErase(this.m_variant, i);
    ArrayErase(this.m_refA, i);
    ArrayErase(this.m_refB, i);
    ArrayErase(this.m_flags, i);
    ArrayErase(this.m_time, i);
  }

  private func Trim() -> Void {
    let n = ArraySize(this.m_id);
    n = Min(n, Min(ArraySize(this.m_sender), ArraySize(this.m_kind)));
    n = Min(n, Min(ArraySize(this.m_variant), ArraySize(this.m_refA)));
    n = Min(n, Min(ArraySize(this.m_refB), Min(ArraySize(this.m_flags), ArraySize(this.m_time))));
    ArrayResize(this.m_id, n);
    ArrayResize(this.m_sender, n);
    ArrayResize(this.m_kind, n);
    ArrayResize(this.m_variant, n);
    ArrayResize(this.m_refA, n);
    ArrayResize(this.m_refB, n);
    ArrayResize(this.m_flags, n);
    ArrayResize(this.m_time, n);
  }

  public func DebugWipe() -> Void {
    ArrayClear(this.m_id); ArrayClear(this.m_sender); ArrayClear(this.m_kind); ArrayClear(this.m_variant);
    ArrayClear(this.m_refA); ArrayClear(this.m_refB); ArrayClear(this.m_flags); ArrayClear(this.m_time);
  }
}
