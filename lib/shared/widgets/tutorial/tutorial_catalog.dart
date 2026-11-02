import '../../../gen_l10n/app_localizations.dart';
import 'tutorial_overlay.dart';

/// 画面に結び付くチュートリアルの識別子。
abstract final class TutorialIds {
  static const library = 'library';
  static const home = 'home';
  static const firstHide = 'first_hide';
  static const firstArchive = 'first_archive';
  static const importPicker = 'import_picker';
}

List<TutorialStep> libraryTutorialSteps(AppLocalizations l10n) => [
  TutorialStep(
    title: l10n.libraryTutorialAddTitle,
    message: l10n.libraryTutorialAddMessage,
    tone: TutorialTone.important,
  ),
  TutorialStep(
    title: l10n.libraryTutorialFindTitle,
    message: l10n.libraryTutorialFindMessage,
  ),
];

List<TutorialStep> homeTutorialSteps(AppLocalizations l10n) => [
  TutorialStep(
    title: l10n.homeTutorialWelcomeTitle,
    message: l10n.homeTutorialWelcomeMessage,
  ),
  TutorialStep(
    title: l10n.homeTutorialSettingsTitle,
    message: l10n.homeTutorialSettingsMessage,
  ),
];

List<TutorialStep> hideTutorialSteps(
  AppLocalizations l10n, {
  required bool hasPasscode,
}) => [
  TutorialStep(
    title: l10n.tutorialFirstHideResultTitle,
    message: l10n.tutorialFirstHideResultMessage,
  ),
  TutorialStep(
    title: hasPasscode
        ? l10n.tutorialFirstHideEncryptionTitle
        : l10n.tutorialFirstHidePasscodeTitle,
    message: hasPasscode
        ? l10n.tutorialFirstHideEncryptionMessage
        : l10n.tutorialFirstHidePasscodeMessage,
    tone: TutorialTone.danger,
  ),
];

List<TutorialStep> archiveTutorialSteps(
  AppLocalizations l10n, {
  required bool hasPasscode,
}) => [
  TutorialStep(
    title: l10n.tutorialFirstArchiveMeaningTitle,
    message: l10n.tutorialFirstArchiveMeaningMessage,
    tone: TutorialTone.important,
  ),
  TutorialStep(
    title: l10n.tutorialFirstArchiveRestoreTitle,
    message: l10n.tutorialFirstArchiveRestoreMessage,
  ),
  if (!hasPasscode)
    TutorialStep(
      title: l10n.tutorialFirstArchivePrivacyTitle,
      message: l10n.tutorialFirstArchivePrivacyMessage,
      tone: TutorialTone.danger,
    ),
];
