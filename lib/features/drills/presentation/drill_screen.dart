import 'dart:async';

import 'package:bah_francais/app/router.dart';
import 'package:bah_francais/core/strings.g.dart';
import 'package:bah_francais/core/theme/app_text_styles.dart';
import 'package:bah_francais/core/time/clock_provider.dart';
import 'package:bah_francais/features/content/data/bundled_content.dart';
import 'package:bah_francais/features/content/domain/content_types.dart';
import 'package:bah_francais/features/drills/domain/drill_type.dart';
import 'package:bah_francais/features/drills/domain/session/drill_session.dart';
import 'package:bah_francais/features/drills/domain/session/noun_item.dart';
import 'package:bah_francais/features/drills/domain/session/session_card.dart';
import 'package:bah_francais/features/drills/presentation/drill_controller.dart';
import 'package:bah_francais/features/drills/presentation/drill_name.dart';
import 'package:bah_francais/features/drills/presentation/drill_providers.dart';
import 'package:bah_francais/features/drills/presentation/widgets/gender_card_view.dart';
import 'package:bah_francais/features/drills/presentation/widgets/prompt_image.dart';
import 'package:bah_francais/features/drills/presentation/widgets/typed_card_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// A drill, full screen: the top bar (× and the cards answered), the card,
/// and the answer area. The back gesture does what × does.
class DrillScreen extends ConsumerStatefulWidget {
  const DrillScreen({required this.drill, super.key});

  /// The drill; null for a mixed session.
  /// (Commencer on Accueil).

  final DrillType? drill;

  @override
  ConsumerState<DrillScreen> createState() => _DrillScreenState();
}

class _DrillScreenState extends ConsumerState<DrillScreen> {
  late final AppLifecycleListener _lifecycle;

  /// When the user left the app, to resume or close the session on return.
  DateTime? _leftAt;

  DrillControllerProvider get _provider =>
      drillControllerProvider(widget.drill);

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onHide: _left, onShow: _returned);
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  void _left() => _leftAt = ref.read(clockProvider).nowUtc();

  /// Back within 30 minutes: the same card. Later: the session is closed,
  /// and the next start opens a new one.
  void _returned() {
    final left = _leftAt;
    _leftAt = null;
    if (left == null) return;
    final away = ref.read(clockProvider).nowUtc().difference(left);
    if (DrillSession.closesAfter(away)) _leave();
  }

  /// × or back: the summary, or straight to Accueil if nothing was answered.
  /// A snackbar still showing (*Trop facile*, *Annuler*) stays with the card.
  void _close() {
    ScaffoldMessenger.of(context).removeCurrentSnackBar();
    final answered =
        ref.read(_provider).hasValue &&
        !ref.read(_provider.notifier).summary.isEmpty;
    if (answered) {
      unawaited(context.push(Routes.drillSummary(widget.drill)));
    } else {
      _leave();
    }
  }

  void _leave() {
    ref.invalidate(dueTodayProvider);
    context.go(Routes.home);
  }

  Future<void> _markKnown() async {
    final controller = ref.read(_provider.notifier);
    final mark = await controller.markKnown();
    if (mark == null || !mounted) return;
    _snackBar(
      Strings.drillMarkedKnown,
      action: Strings.commonUndo,
      onAction: () => controller.undoKnown(mark),
    );
  }

  /// The buttons and accent bar at the bottom, or the message's button.
  final GlobalKey _controls = GlobalKey();

  /// A snackbar with its one action, for 5 seconds. It floats above the
  /// buttons and accent bar, so the next answer can be given meanwhile.
  /// *Je le connais*'s *Annuler* is the one there is.
  void _snackBar(
    String message, {
    required String action,
    required VoidCallback onAction,
  }) {
    final controls = _controls.currentContext?.size?.height ?? 0;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(seconds: 5),
          // With an action, a snackbar would otherwise stay until dismissed.
          persist: false,
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.fromLTRB(16, 0, 16, controls + 8),
          action: SnackBarAction(label: action, onPressed: onAction),
        ),
      );
  }

  /// The view of [card], from its question to its correction; one per card,
  /// so what was typed carries over.
  Widget _cardView(
    SessionCard card, {
    required CardFeedback? feedback,
    required Widget? notice,
  }) {
    final controller = ref.read(_provider.notifier);
    return switch (card) {
      GenderCard() => GenderCardView(
        key: ObjectKey(card),
        card: card,
        feedback: feedback,
        notice: notice,
        onChoose: controller.choose,
        onTooEasy: controller.tooEasy,
        onTypo: controller.markTypo,
        onNext: controller.next,
        controlsKey: _controls,
      ),
      TypedCard() => TypedCardView(
        key: ObjectKey(card),
        card: card,
        feedback: feedback,
        notice: notice,
        prompt: switch (card) {
          VocabularyCard(:final prompt) => _Prompt(prompt),
          ConjugationCard() => const SizedBox.shrink(),
        },
        subline: switch (card) {
          ConjugationCard(:final item) => _VerbAndTense(
            infinitive: item.infinitive,
            tense: item.tense,
          ),
          VocabularyCard() => null,
        },
        liveFeedback: ref
            .watch(drillDisplaySettingsProvider(card.card.drill))
            .liveFeedback,
        onSubmit: controller.submit,
        onTooEasy: controller.tooEasy,
        onGiveUp: controller.giveUp,
        onTypo: controller.markTypo,
        onNext: controller.next,
        controlsKey: _controls,
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(_provider);
    final controller = ref.read(_provider.notifier);
    final view = state.value;
    final answered = view == null ? 0 : controller.summary.answered;
    final onCard = view is CardQuestion || view is CardFeedback;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _close();
      },
      child: Scaffold(
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _TopBar(
                answered: answered,
                onClose: _close,
                onKnown: onCard ? _markKnown : null,
              ),
              // A mixed session names the drill of the card on screen.
              if (widget.drill == null)
                if (view
                    case CardQuestion(:final card) || CardFeedback(:final card))
                  _DrillLabel(card.card.drill),
              Expanded(
                child: switch (view) {
                  null => const _Preparing(),
                  // One view per card, from its question to its correction.
                  CardQuestion(:final card) ||
                  CardFeedback(:final card) => _cardView(
                    card,
                    feedback: view is CardFeedback ? view : null,
                    notice: view is CardQuestion && view.startsFreePractice
                        ? const _FreePracticeNotice()
                        : null,
                  ),
                  GoalReached() => _Message(
                    message: Strings.drillDailyGoalReached,
                    action: Strings.sessionSummaryFinish,
                    buttonKey: _controls,
                    onAction: _close,
                  ),
                  NoCards() => _Message(
                    message: Strings.drillNoCards,
                    action: Strings.drillOpenSettings,
                    buttonKey: _controls,
                    onAction: () => context.go(Routes.settings),
                  ),
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// × and the number of cards answered; *Je le connais* at the right while a
/// card is shown.
class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.answered,
    required this.onClose,
    required this.onKnown,
  });

  final int answered;
  final VoidCallback onClose;
  final VoidCallback? onKnown;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          IconButton(
            onPressed: onClose,
            icon: const Icon(Icons.close),
            tooltip: Strings.accessibilityCloseSession,
          ),
          Expanded(child: Text(Strings.drillCardsAnswered(n: answered))),
          // With large text the label wraps rather than overflowing.
          if (onKnown != null)
            Flexible(
              flex: 2,
              child: TextButton(
                onPressed: onKnown,
                child: const Text(
                  Strings.drillIKnowIt,
                  textAlign: TextAlign.end,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// *Tout est à jour !*, above the card: the session has just moved into
/// free practice.
class _FreePracticeNotice extends StatelessWidget {
  const _FreePracticeNotice();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
    child: Text(
      '${Strings.drillAllCaughtUp}\n${Strings.drillFreePractice}',
      style: Theme.of(context).textTheme.bodyMedium,
    ),
  );
}

/// One of the noun's images, or its definition, in body text so the
/// sentence below stands out (decision 70).
class _Prompt extends StatelessWidget {
  const _Prompt(this.prompt);

  final VocabularyPrompt prompt;

  @override
  Widget build(BuildContext context) => switch (prompt) {
    ImagePrompt(:final imageId) => PromptImage(imageId),
    DefinitionPrompt(:final definition) => Text(
      definition,
      textAlign: TextAlign.center,
      style: Theme.of(context).textTheme.bodyLarge,
    ),
  };
}

/// Under a Conjugaison sentence: the infinitive, in bold, and the tense.
class _VerbAndTense extends StatelessWidget {
  const _VerbAndTense({required this.infinitive, required this.tense});

  final String infinitive;
  final Tense tense;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodyLarge;
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 12,
      children: [
        Text(
          infinitive,
          style: style?.merge(AppTextStyles.of(context).emphasis),
        ),
        Text(switch (tense) {
          Tense.present => Strings.tensesPresent,
          Tense.passeCompose => Strings.tensesPasseCompose,
          Tense.imparfait => Strings.tensesImparfait,
          Tense.futurSimple => Strings.tensesFuturSimple,
        }, style: style),
      ],
    );
  }
}

/// Under the top bar in a mixed session: the drill of the card on screen.
class _DrillLabel extends StatelessWidget {
  const _DrillLabel(this.drill);

  final DrillType drill;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16),
    child: Text(
      drillName(drill),
      textAlign: TextAlign.center,
      style: Theme.of(context).textTheme.labelLarge,
    ),
  );
}

/// A one-line message instead of a card, with the one thing to do next.
class _Message extends StatelessWidget {
  const _Message({
    required this.message,
    required this.action,
    required this.onAction,
    this.buttonKey,
  });

  final String message;
  final String action;
  final VoidCallback onAction;

  /// On the button, so a snackbar can sit above it.
  final Key? buttonKey;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Center(
              child: Text(
                message,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
          ),
          FilledButton(
            key: buttonKey,
            onPressed: onAction,
            child: Text(action),
          ),
        ],
      ),
    );
  }
}

/// The session is opening, or the content is still being imported.
class _Preparing extends ConsumerWidget {
  const _Preparing();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final importing = !ref.watch(contentReadyProvider).hasValue;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          if (importing) ...[
            const SizedBox(height: 16),
            const Text(Strings.homePreparingContent),
          ],
        ],
      ),
    );
  }
}
