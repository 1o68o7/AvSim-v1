/** Assure un Result /api/simulate pour les vues Analyste (Bilan, Équipage, …).

Source unique Python — pas de recalcul des grandeurs §9.2 ni du détail poste.
*/
import { useCallback, useEffect, useRef } from "react";
import { ApiError, api } from "../api";
import { useApp, useSelectedClass } from "../state";

export function useEnsureSimulate() {
  const {
    role,
    boatClass,
    classes,
    setClasses,
    result,
    setResult,
    busy,
    setBusy,
    networkError,
    setNetworkError,
  } = useApp();
  const selected = useSelectedClass();
  const inflight = useRef(false);

  // Catalogue classes (badge Validée/Bêta même hors Vue Bateau)
  useEffect(() => {
    if (!role || classes.length) return;
    api
      .classes(role)
      .then((r) => setClasses(r.classes))
      .catch((e: ApiError) => setNetworkError(e.message));
  }, [role, classes.length, setClasses, setNetworkError]);

  const run = useCallback(async () => {
    if (!role || inflight.current) return;
    inflight.current = true;
    setBusy(true);
    try {
      const res = await api.simulate(role, {
        boat_class: boatClass,
        n_strokes: 6,
        n_discard: 2,
      });
      setResult(res);
      setNetworkError(null);
    } catch (e) {
      setNetworkError(e instanceof ApiError ? e.message : String(e));
    } finally {
      setBusy(false);
      inflight.current = false;
    }
  }, [role, boatClass, setBusy, setResult, setNetworkError]);

  // Si pas de résultat pour la classe courante → appeler /api/simulate
  useEffect(() => {
    if (!role) return;
    if (result && result.validation?.code === boatClass) return;
    void run();
  }, [role, boatClass, result, run]);

  return {
    result:
      result && result.validation?.code === boatClass ? result : null,
    busy,
    networkError,
    retry: run,
    selected,
    boatClass,
  };
}
