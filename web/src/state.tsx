import {
  createContext,
  useContext,
  useMemo,
  useState,
  type ReactNode,
} from "react";
import type { ClassInfo, Role, SimulateResult } from "./api";

type Ctx = {
  role: Role | null;
  setRole: (r: Role | null) => void;
  boatClass: string;
  setBoatClass: (c: string) => void;
  classes: ClassInfo[];
  setClasses: (c: ClassInfo[]) => void;
  result: SimulateResult | null;
  setResult: (r: SimulateResult | null) => void;
  busy: boolean;
  setBusy: (b: boolean) => void;
  networkError: string | null;
  setNetworkError: (e: string | null) => void;
};

const AppCtx = createContext<Ctx | null>(null);

export function AppProvider({ children }: { children: ReactNode }) {
  const [role, setRole] = useState<Role | null>(null);
  const [boatClass, setBoatClass] = useState("8+");
  const [classes, setClasses] = useState<ClassInfo[]>([]);
  const [result, setResult] = useState<SimulateResult | null>(null);
  const [busy, setBusy] = useState(false);
  const [networkError, setNetworkError] = useState<string | null>(null);

  const value = useMemo(
    () => ({
      role,
      setRole,
      boatClass,
      setBoatClass,
      classes,
      setClasses,
      result,
      setResult,
      busy,
      setBusy,
      networkError,
      setNetworkError,
    }),
    [role, boatClass, classes, result, busy, networkError],
  );

  return <AppCtx.Provider value={value}>{children}</AppCtx.Provider>;
}

export function useApp() {
  const ctx = useContext(AppCtx);
  if (!ctx) throw new Error("useApp hors AppProvider");
  return ctx;
}

export function useSelectedClass(): ClassInfo | undefined {
  const { classes, boatClass } = useApp();
  return classes.find((c) => c.code === boatClass);
}
