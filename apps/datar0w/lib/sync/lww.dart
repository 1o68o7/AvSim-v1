/// Last-write-wins sur [updated_at].
bool remoteWins(DateTime localUpdated, DateTime remoteUpdated) =>
    remoteUpdated.isAfter(localUpdated);

T pickLww<T>({
  required T local,
  required T remote,
  required DateTime localUpdated,
  required DateTime remoteUpdated,
}) =>
    remoteWins(localUpdated, remoteUpdated) ? remote : local;
