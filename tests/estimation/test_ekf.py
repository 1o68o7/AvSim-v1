"""EKF tableau de bord — tests unitaires sans simulation lourde."""
from __future__ import annotations

import numpy as np

from avsim.estimation.ekf import DashboardEKF, EKFConfig


def test_ekf_tracks_constant_velocity():
    rng = np.random.default_rng(0)
    t = np.linspace(0.0, 5.0, 101)
    V_true = 4.2
    v_meas = V_true + rng.normal(0.0, 0.08, size=t.shape)
    ekf = DashboardEKF(EKFConfig(v0=3.0))
    out = ekf.run(t, v_meas=v_meas, v_R=0.08**2)
    # après convergence, erreur moyenne faible
    err = np.mean(np.abs(out["V"][20:] - V_true))
    assert err < 0.05


def test_ekf_tracks_com_with_noisy_proxy():
    rng = np.random.default_rng(1)
    t = np.linspace(0.0, 4.0, 81)
    com_true = 0.15 * np.sin(2 * np.pi * t / 2.0)
    com_meas = com_true + rng.normal(0.0, 0.03, size=t.shape)
    # q_com un peu plus haut pour suivre une sinusoïde (pas une constante)
    ekf = DashboardEKF(EKFConfig(q_com=0.05**2, x_com0=0.0))
    out = ekf.run(t, com_meas=com_meas, com_R=0.03**2)
    err = np.mean(np.abs(out["x_com"][10:] - com_true[10:]))
    assert err < 0.05


def test_ekf_imu_accel_improves_velocity_coast():
    """Sans mesure V, l'accel IMU doit propager V raisonnablement."""
    t = np.linspace(0.0, 2.0, 41)
    accel = np.full_like(t, 0.5)
    V_true = 3.0 + 0.5 * t
    ekf = DashboardEKF(EKFConfig(v0=3.0, q_v=1e-4))
    out = ekf.run(t, accel=accel)
    err = np.mean(np.abs(out["V"] - V_true))
    assert err < 0.15


def test_ekf_subset_without_com_leaves_com_near_prior():
    t = np.linspace(0.0, 1.0, 21)
    ekf = DashboardEKF(EKFConfig(x_com0=0.0, q_com=1e-6))
    out = ekf.run(t, v_meas=np.full_like(t, 4.0), v_R=0.01**2)
    assert np.max(np.abs(out["x_com"])) < 0.05


def test_ekf_reset_and_update_helpers():
    ekf = DashboardEKF()
    ekf.reset(v=5.0, x_com=-0.1)
    assert ekf.V == 5.0 and ekf.x_com == -0.1
    ekf.update_velocity(5.1, 0.01**2)
    assert abs(ekf.V - 5.1) < 0.05
    ekf.update_com(0.0, 0.02**2)
    assert abs(ekf.x_com) < 0.05
