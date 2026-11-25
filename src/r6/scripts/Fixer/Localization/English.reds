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
    this.Text("FX-UI-Next-Wait", "Dino is watching. Chance he calls today: {0}% (guaranteed within {1} days).");
    this.Text("FX-UI-Next-OfferOpen", "Dino made you an offer. Answer it in the Inbox.");
    this.Text("FX-UI-Next-Partner", "Work Dino's jobs on the MAP. He'll get greedy in about {0} more job(s).");
    this.Text("FX-UI-Next-RaiseOpen", "Dino wants a bigger cut. Answer him in the Inbox. Refusing means war.");
    this.Text("FX-UI-Next-War", "War with Dino: you hold {0} of {1} blocks. Dino's strength {2}. Take them all, or three in four with him down to 20.");
    this.Text("FX-UI-Next-Fixer", "City Center is yours. Every job in the city is on your MAP.");
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
    this.Text("FX-UI-Tab-Map", "MAP");
    this.Text("FX-UI-Tab-Ops", "OPS");
    this.Text("FX-UI-Accept", "ACCEPT");
    this.Text("FX-UI-Decline", "DECLINE");
    this.Text("FX-UI-Refuse", "REFUSE");
    this.Text("FX-UI-RefuseMeansWar", "Refusing means war.");
    this.Text("FX-UI-Newer", "< NEWER");
    this.Text("FX-UI-Older", "OLDER >");
    this.Text("FX-UI-Heat", "NCPD Heat {0} | Arasaka Heat {1}");
    this.Text("FX-UI-Earned", "Earned from the business: {0} eddies");
    this.Text("FX-Status-6", "Guarding");

    // ---- Jobs ----
    this.Text("FX-JobType-0", "Theft");
    this.Text("FX-JobType-1", "Extraction");
    this.Text("FX-JobType-2", "Sabotage");
    this.Text("FX-JobType-3", "Netrun");
    this.Text("FX-JobType-4", "Escort");
    this.Text("FX-JobType-5", "Courier run");
    this.Text("FX-JobType-6", "Clear-out");
    this.Text("FX-JobType-7", "Psycho hunt");
    this.Text("FX-JobType-8", "Vehicle job");
    this.Text("FX-Job-At", "{0} at {1}");
    this.Text("FX-Job-Unknown", "a job");
    this.Text("FX-Kind-0", "Dino's job");
    this.Text("FX-Kind-1", "Your job");
    this.Text("FX-Kind-2", "City job: {0}");
    this.Text("FX-Kind-3", "Strike on Dino's turf");
    this.Text("FX-Site-Gig", "gig");
    this.Text("FX-Site-NCPD", "NCPD scanner");
    this.Text("FX-Site-Psycho", "cyberpsycho");
    this.Text("FX-Site-Vehicle", "car job");
    this.Text("FX-Site-Courier", "courier");
    this.Text("FX-Outcome-0", "Under way");
    this.Text("FX-Outcome-1", "Success");
    this.Text("FX-Outcome-2", "Partial");
    this.Text("FX-Outcome-3", "Failed");
    this.Text("FX-Outcome-4", "Disaster");
    this.Text("FX-Fate-0", "is fine");
    this.Text("FX-Fate-1", "is in a ripperdoc's chair");
    this.Text("FX-Fate-2", "got picked up by the NCPD");
    this.Text("FX-Fate-3", "didn't make it");
    this.Text("FX-FateLine-0", "Shook it off.");
    this.Text("FX-FateLine-1", "In a ripperdoc's chair for a while.");
    this.Text("FX-FateLine-2", "The NCPD picked them up after.");
    this.Text("FX-FateLine-3", "They didn't make it.");

    // ---- The map and the job card ----
    this.Text("FX-Map-NoData", "No map data yet. The map plots fast-travel points the game knows about: find a few data terms in City Center and it fills in. Jobs without a position are listed under the map.");
    this.Text("FX-Map-You", "YOU");
    this.Text("FX-Legend-Dino", "Dino's job");
    this.Text("FX-Legend-Strike", "Strike");
    this.Text("FX-Legend-Yours", "Your job");
    this.Text("FX-Legend-Gig", "Gig");
    this.Text("FX-Legend-NCPD", "NCPD");
    this.Text("FX-Legend-Psycho", "Psycho");
    this.Text("FX-Legend-Vehicle", "Car job");
    this.Text("FX-Legend-Courier", "Courier");
    this.Text("FX-Legend-YourBlock", "Your block");
    this.Text("FX-Legend-DinoBlock", "Dino's block");
    this.Text("FX-Card-Facts", "Difficulty {0}/5 | {1}h | Crew needed: {2}");
    this.Text("FX-Card-Pay", "Pays {0} eddies");
    this.Text("FX-Card-DinoTakes", "Dino takes {0}%");
    this.Text("FX-Card-Roles", "Best for: {0}, then {1}");
    this.Text("FX-Card-Heat", "Heat +{0}");
    this.Text("FX-Card-Arasaka", "ARASAKA TARGET");
    this.Text("FX-Card-Pick", "PICK YOUR CREW");
    this.Text("FX-Card-NobodyFree", "Nobody's free: wait for the crew to come back or hire more.");
    this.Text("FX-Card-Cut", "CREW CUT {0}%");
    this.Text("FX-Card-Success", "SUCCESS {0}%");
    this.Text("FX-Card-Take", "You get {0} eddies if it goes clean.");
    this.Text("FX-Card-PickMore", "Pick {0} more.");
    this.Text("FX-Card-Send", "SEND CREW");
    this.Text("FX-Card-ShowOnMap", "SHOW ON MAP");
    this.Text("FX-Card-Running", "Under way: {0}. Back in {1}h.");
    this.Text("FX-Card-Odds", "Odds: {0}%");
    this.Text("FX-Block-Yours", "Yours.");
    this.Text("FX-Block-Dinos", "Dino holds it.");
    this.Text("FX-Block-Guard", "Guard: {0}");
    this.Text("FX-Block-NoGuard", "nobody");
    this.Text("FX-Block-GuardHelp", "A guard can hold the block when Dino comes for it. Guards don't go on jobs.");
    this.Text("FX-Block-NextGuard", "NEXT GUARD");
    this.Text("FX-Block-Unguard", "NO GUARD");
    this.Text("FX-Block-StrikeHelp", "Strike jobs on Dino's blocks show up on the map. Win one and the block is yours.");
    this.Text("FX-Help-Partner", "Dino's jobs are on the map. Click one to see the crew it needs, the pay, and the odds for the people you pick.");
    this.Text("FX-Help-War", "Take Dino's blocks. Click a strike job to send a crew, or one of your blocks to put a guard on it.");
    this.Text("FX-Help-Fixer", "Every job in the city is yours: gigs, NCPD scanner, psychos, car jobs. Send a crew or go yourself.");
    this.Text("FX-Help-Counts", "On the board: {0} | Under way: {1}");

    // ---- Ops ----
    this.Text("FX-Ops-HeatNcpd", "NCPD Heat");
    this.Text("FX-Ops-HeatArasaka", "Arasaka Heat");
    this.Text("FX-Ops-Running", "UNDER WAY");
    this.Text("FX-Ops-RunningLine", "{0}: back in {1}h");
    this.Text("FX-Ops-Results", "LATEST RESULTS");
    this.Text("FX-Ops-ResultLine", "{0}: {1}, {2} eddies");
    this.Text("FX-Ops-Ledger", "LEDGER");
    this.Text("FX-Ops-LedgerLine", "Day {0} | {1} | +{2}");
    this.Text("FX-Ops-LedgerJob", "Job");
    this.Text("FX-Ops-LedgerTurf", "Turf");
    this.Text("FX-Ops-None", "Nothing yet.");

    // ---- Messages: Dino ----
    this.Text("FX-Msg-DinoOffer-0", "Let's not dance, merc. City Center has more work than I have hands. You and your crew run the jobs I hand you, I take {0}% off the top, everybody eats. Yes or no?");
    this.Text("FX-Msg-DinoOfferAccepted-0", "Smart. Your first jobs are on the board. Don't make me regret this.");
    this.Text("FX-Msg-DinoOfferDeclined-0", "Your call. The offer won't sit on the table forever.");
    this.Text("FX-Msg-DinoRaise-0", "Business is good, partner. Too good. My cut goes to {0}%. Take it, or we have a problem.");
    this.Text("FX-Msg-DinoWar-0", "You got big, merc. Too big for my streets. From now on you're competition, and I bury competition.");
    this.Text("FX-Msg-WarBlockLost-0", "Took {0} back. Thought you could hold my streets?");
    this.Text("FX-Msg-WarPoached-0", "{0} works for me now. Pays to be on the winning side.");
    this.Text("FX-Msg-WarTipoff-0", "Hope you like the NCPD. I gave them your address.");
    this.Text("FX-Msg-DinoDefeated-0", "Enjoy it while it lasts, merc. I'm not done. City Center is yours... for now.");

    // ---- Messages: the crew ----
    this.Text("FX-Msg-JobSuccess-0", "Done. {0} went clean. Your share's in: {1} eddies.");
    this.Text("FX-Msg-JobSuccess-1", "{0}: in and out, no fuss. {1} eddies on their way to you.");
    this.Text("FX-Msg-JobSuccess-2", "Job's wrapped. {0}. Client paid, you got {1}. Drinks are on you.");
    this.Text("FX-Msg-JobPartial-0", "{0} got messy. Half the take: {1} eddies. Could've been worse.");
    this.Text("FX-Msg-JobPartial-1", "We got some of it at {0}. Client paid half: {1} eddies.");
    this.Text("FX-Msg-JobFail-0", "{0} went sideways. We pulled out with nothing. Sorry, boss.");
    this.Text("FX-Msg-JobFail-1", "Blew it at {0}. No pay. We'll do better.");
    this.Text("FX-Msg-JobDisaster-0", "{0} was a setup. {2} {3}. The rest of us got out. Barely.");
    this.Text("FX-Msg-JobDisaster-1", "Everything went wrong at {0}. {2} {3}.");
    this.Text("FX-Msg-JobLost-0", "Nobody's answering from {0}. {2} {3}.");
    this.Text("FX-Msg-MemberRecovered-0", "Back on my feet. Ready when you are.");
    this.Text("FX-Msg-MemberReleased-0", "The NCPD let me go. Didn't say a word. I need work.");
    this.Text("FX-Msg-MemberDeserted-0", "Found a better gig. Don't call.");
    this.Text("FX-Msg-MemberDeserted-1", "I'm out. The cut's an insult and you know it.");
    this.Text("FX-Msg-MemberBetrayed-0", "{0} sold you out. The NCPD knows about your operation now. Heat's up.");
    this.Text("FX-Msg-MemberLevelUp-0", "Getting good at this. Call me level {0}.");
    this.Text("FX-Msg-WarBlockDefended-0", "Dino sent people to {0}. They left in a hurry. The block's still ours.");

    // ---- Messages: the network ----
    this.Text("FX-Msg-WarBlockTaken-0", "{0} is yours. Dino's people cleared out.");
    this.Text("FX-Msg-WarAmbush-0", "Dino's people jumped {0}. {1}");
    this.Text("FX-Msg-CityBoardOpen-0", "City Center is yours. Every job in the city is on your map now: gigs, NCPD scanner, psychos, car jobs. Send the crew or go yourself.");
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
