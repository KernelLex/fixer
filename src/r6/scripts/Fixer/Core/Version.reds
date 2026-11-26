module Fixer

// The mod's version, shown in the log and on the terminal's status page.
public func FXVersion() -> String = "0.4.0";

// The saved-data layout version. Every book writes it on first use; a book that reads a lower number on load
// migrates it (FXCareerBook.Migrate and friends).
public func FXSaveVersion() -> Int32 = 2;
