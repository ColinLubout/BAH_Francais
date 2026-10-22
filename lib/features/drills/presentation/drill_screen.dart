import 'dart:async';

import 'package:bah_francais/app/router.dart';
import 'package:bah_francais/core/strings.g.dart';
import 'package:bah_francais/core/time/clock_provider.dart';
import 'package:bah_francais/features/content/data/bundled_content.dart';
import 'package:bah_francais/features/drills/domain/drill_type.dart';
import 'package:bah_francais/features/drills/domain/session/drill_session.dart';
import 'package:bah_francais/features/drills/domain/session/vocabulary_item.dart';
import 'package:bah_francais/features/drills/presentation/drill_controller.dart';
import 'package:bah_francais/features/drills/presentation/drill_providers.dart';
import 'package:bah_francais/features/drills/presentation/widgets/prompt_image.dart';
import 'package:bah_francais/features/drills/presentation/widgets/vocabulary_card_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// A drill, full screen: the top bar (× and the cards answered), the card,
/// and the answer area. The back gesture does what × does.
class DrillScreen extends ConsumerStatefulWidget {
  const DrillScreen({required this.drill, super.key});

  final DrillType drill;

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

  /// *Valider*. A Correct answer moves straight on; the first time the word
  /// is answered, *Trop facile* stays on offer for a few seconds
  /// (decision 71).
  Future<void> _submit(String typed, {required bool capsGrade}) async {
    final controller = ref.read(_provider.notifier);
    final offer = await controller.submit(typed, capsGrade: capsGrade);
    if (offer == null || !mounted) return;
    _snackBar(
      Strings.drillResultCorrect,
      action: Strings.drillTooEasy,
      onAction: () => controller.tooEasy(offer),
    );
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
              Expanded(
                child: switch (view) {
                  null => const _Preparing(),
                  // One view per card, from its question to its correction.
                  CardQuestion(:final card) ||
                  CardFeedback(:final card) => VocabularyCardView(
                    key: ObjectKey(card),
                    card: card,
                    feedback: view is CardFeedback ? view : null,
                    notice: view is CardQuestion && view.startsFreePractice
                        ? const _FreePracticeNotice()
                        : null,
                    prompt: _Prompt(card.prompt),
                    liveFeedback: ref
                        .watch(drillDisplaySettingsProvider(widget.drill))
                        .liveFeedback,
                    onSubmit: _submit,
                    onGiveUp: controller.giveUp,
                    onTypo: controller.markTypo,
                    onNext: controller.next,
                    controlsKey: _controls,
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
