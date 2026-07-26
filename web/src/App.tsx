import { Navigate, Route, Routes } from "react-router-dom";
import { AppProvider, useApp } from "./state";
import { RoleSelect } from "./surfaces/RoleSelect";
import { AnalystShell } from "./surfaces/analyst/AnalystShell";
import { BoatView } from "./surfaces/analyst/BoatView";
import { StrokeView } from "./surfaces/analyst/StrokeView";
import { BalanceView } from "./surfaces/analyst/BalanceView";
import { CrewView } from "./surfaces/analyst/CrewView";
import {
  DetectabilityView,
  ObservabilityView,
  SensitivityView,
  SensorsView,
} from "./surfaces/analyst/BlockedViews";
import {
  CoachLiveView,
  CoachReplayView,
  ProductShell,
  RowerView,
  TeamView,
} from "./surfaces/product/ProductShell";

function Gate() {
  const { role } = useApp();
  if (!role) return <RoleSelect />;
  return (
    <Routes>
      {role === "analyst" ? (
        <Route path="/analyst" element={<AnalystShell />}>
          <Route index element={<Navigate to="bateau" replace />} />
          <Route path="bateau" element={<BoatView />} />
          <Route path="coup" element={<StrokeView />} />
          <Route path="bilan" element={<BalanceView />} />
          <Route path="equipage" element={<CrewView />} />
          <Route path="capteurs" element={<SensorsView />} />
          <Route path="observabilite" element={<ObservabilityView />} />
          <Route path="sensibilite" element={<SensitivityView />} />
          <Route path="detectabilite" element={<DetectabilityView />} />
        </Route>
      ) : (
        <Route path="/product" element={<ProductShell />}>
          <Route index element={<Navigate to="rameur" replace />} />
          <Route path="rameur" element={<RowerView />} />
          <Route path="team" element={<TeamView />} />
          <Route path="coach-live" element={<CoachLiveView />} />
          <Route path="coach-replay" element={<CoachReplayView />} />
        </Route>
      )}
      <Route
        path="*"
        element={
          <Navigate
            to={role === "analyst" ? "/analyst/bateau" : "/product/rameur"}
            replace
          />
        }
      />
    </Routes>
  );
}

export default function App() {
  return (
    <AppProvider>
      <Gate />
    </AppProvider>
  );
}
