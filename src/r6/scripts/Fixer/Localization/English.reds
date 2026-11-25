module Fixer
import Codeware.Localization.*

// Every line the player reads, as a key. Numbered slots {0} {1} take names and numbers (FXFormat).
// A translation is a new package class returned by FXLocalizationProvider.GetPackage for its language.

public class FXLocalizationProvider extends ModLocalizationProvider {
  public func GetPackage(language: CName) -> ref<ModLocalizationPackage> {
    // English only for now. Every language gets it, so nobody sees a raw key.
    return new FXEnglish();
  }

  public func GetFallback() -> CName {
    return n"en-us";
  }
}

public class FXEnglish extends ModLocalizationPackage {
  protected func DefineTexts() -> Void {
    // ---- Stages ----
    this.Text("FX-Stage-0", "Merc");
    this.Text("FX-Stage-1", "Recruiter");
    this.Text("FX-Stage-2", "Candidate");
    this.Text("FX-Stage-3", "Dino's partner");
    this.Text("FX-Stage-4", "At war with Dino");
    this.Text("FX-Stage-5", "Fixer of City Center");

    // ---- Roles, traits, status ----
    this.Text("FX-Role-0", "Solo");
    this.Text("FX-Role-1", "Netrunner");
    this.Text("FX-Role-2", "Techie");
    this.Text("FX-Role-3", "Nomad");
    this.Text("FX-Role-4", "Face");
    this.Text("FX-Trait-0", "Steady");
    this.Text("FX-Trait-1", "Greedy");
    this.Text("FX-Trait-2", "Loyal");
    this.Text("FX-Trait-3", "Reckless");
    this.Text("FX-Trait-4", "Cautious");
    this.Text("FX-Trait-5", "Ex-corpo");
    this.Text("FX-Trait-6", "Ex-gang");
    this.Text("FX-Status-0", "Idle");
    this.Text("FX-Status-1", "On a job");
    this.Text("FX-Status-2", "Injured");
    this.Text("FX-Status-3", "Arrested");
    this.Text("FX-Status-4", "Dead");
    this.Text("FX-Status-5", "Gone");

    // ---- Senders ----
    this.Text("FX-Sender-Dino", "Dino Dinovic");
    this.Text("FX-Sender-Net", "FIXER//NET");

    // ---- Messages: a recruit asks for work. {0} = the gig, {1} = their role ----
    this.Text("FX-Msg-LeadOffer-0", "Saw what you pulled at {0}. Clean work. I'm a {1} and I want a crew that doesn't fold. You hiring?");
    this.Text("FX-Msg-LeadOffer-1", "Heard about {0}. Word travels. I do {1} work, I don't miss and I don't talk. Got a spot for me?");
    this.Text("FX-Msg-LeadOffer-2", "You're the merc from {0}, right? I need steady work and you look like steady work. {1}, five years on the street.");
    this.Text("FX-Msg-LeadOffer-3", "Your name's going around after {0}. I want in. {1}. Ask anyone I've worked with. The ones still breathing.");
    this.Text("FX-Msg-LeadOffer-NoGig", "your last job");
    this.Text("FX-Msg-LeadHired-0", "Good. I'll be around when you need me.");
    this.Text("FX-Msg-LeadHired-1", "You won't regret it. Probably.");
    this.Text("FX-Msg-LeadHired-2", "Deal. Text me when there's work.");
    this.Text("FX-Msg-LeadDeclined-0", "Your loss, choom.");
    this.Text("FX-Msg-LeadDeclined-1", "Fine. Plenty of fixers in this city.");
    this.Text("FX-Msg-LeadExpired-0", "Guess that's a no. Found other work.");
    this.Text("FX-Msg-LeadExpired-1", "Took too long. I'm moving on.");
    this.Text("FX-Msg-RosterFull-0", "{0} wants in, but your crew is full ({1}). Let someone go or turn them down.");

    // ---- Messages: Dino and the network ----
    this.Text("FX-Msg-StageRecruiter-0", "Your name's coming up, merc. People are asking who you are, and some of them want work. Careful who you trust.");
    this.Text("FX-Msg-StageCandidate-0", "You've been busy, and a lot of it on my streets. I've been watching. Keep your nose clean and we'll talk business.");
    this.Text("FX-Msg-Welcome-0", "Terminal online. Every gig you finish builds your name. Offers, crew and messages land here.");

    // ---- Terminal ----
    this.Text("FX-UI-Title", "FIXER//NET");
    this.Text("FX-UI-Tab-Status", "STATUS");
    this.Text("FX-UI-Tab-Inbox", "INBOX");
    this.Text("FX-UI-Tab-Crew", "CREW");
    this.Text("FX-UI-Tab-Debug", "DEBUG");
    this.Text("FX-UI-Hire", "HIRE");
    this.Text("FX-UI-Pass", "PASS");
    this.Text("FX-UI-Stage", "Standing: {0}");
    this.Text("FX-UI-Gigs", "Gigs finished: {0} (City Center: {1}) | Failed: {2}");
    this.Text("FX-UI-StreetCred", "Street Cred: {0}");
    this.Text("FX-UI-Crew", "Crew: {0} of {1}");
    this.Text("FX-UI-Next", "Next: {0}");
    this.Text("FX-UI-Next-Recruiter", "finish {0} more gig(s) and people start asking you for work.");
    this.Text("FX-UI-Next-Candidate", "{0}");
    this.Text("FX-UI-Next-NeedGigs", "{0} more gig(s)");
    this.Text("FX-UI-Next-NeedCC", "{0} more on Dino's turf (Downtown, Corpo Plaza)");
    this.Text("FX-UI-Next-NeedCred", "Street Cred {0}");
    this.Text("FX-UI-Next-Wait", "Dino is watching. Keep working (his offer comes in a later update).");
    this.Text("FX-UI-Next-Later", "More of the business opens in a later update.");
    this.Text("FX-UI-Inbox-Empty", "No messages yet.");
    this.Text("FX-UI-Crew-Empty", "Nobody on the crew yet. Recruits will text you once your name gets around.");
    this.Text("FX-UI-Lead-Waiting", "Waiting for your answer, {0}h left.");
    this.Text("FX-UI-Lead-Hired", "Hired.");
    this.Text("FX-UI-Lead-Declined", "Turned down.");
    this.Text("FX-UI-Lead-Expired", "Moved on.");
    this.Text("FX-UI-Ago-Now", "just now");
    this.Text("FX-UI-Ago-Hours", "{0}h ago");
    this.Text("FX-UI-Ago-Days", "{0}d ago");
    this.Text("FX-UI-Member", "{0} | {1} | Lv {2} | Skill {3} | Loyalty {4} | {5} | {6}");
    this.Text("FX-UI-Disabled", "The Fixer mod is switched off in Mod Settings.");
    this.Text("FX-UI-Version", "Fixer {0}");
  }
}

// Look a key up. Codeware returns the key itself when a line is missing, which shows up on screen and in the log,
// rather than an empty string that hides the bug.
public func FXText(game: GameInstance, key: String) -> String {
  let loc = LocalizationSystem.GetInstance(game);
  if !IsDefined(loc) {
    return key;
  }
  return loc.GetText(key);
}

public func FXFormat(text: String, args: array<String>) -> String {
  let out = text;
  let n = ArraySize(args);
  let i = 0;
  while i < n {
    out = StrReplaceAll(out, s"{\(i)}", args[i]);
    i += 1;
  }
  return out;
}

public func FXTextF(game: GameInstance, key: String, args: array<String>) -> String {
  return FXFormat(FXText(game, key), args);
}
