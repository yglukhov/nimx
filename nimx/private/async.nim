import std/async
export async

when defined(js):
  proc asyncCheck*[T](future: Future[T]) =
    # Exceptions are always raised the Web Promise API.
    discard
