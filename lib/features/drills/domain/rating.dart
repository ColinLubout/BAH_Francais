/// The four FSRS ratings. The user never picks one: grading decides it from
/// the answer, and the override buttons adjust it.
enum Rating {
  again(1),
  hard(2),
  good(3),
  easy(4);

  Rating(this.value);

  /// The rating's number in FSRS's formulas.
  final int value;
}
