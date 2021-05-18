

class JsEvalResult {
  final String? _stringResult;
  final dynamic rawResult;
  final bool isPromise;
  final bool isError;

  JsEvalResult(this._stringResult, this.rawResult,
      {this.isError = false, this.isPromise = false});

  String get stringResult => _stringResult == null ? rawResult.toString() : _stringResult!;

  toString() => stringResult;
}