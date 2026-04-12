"use client";

import { useCallback, useEffect, useRef, useState } from "react";
import {
  Camera,
  CheckCircle2,
  ChevronDown,
  ChevronUp,
  Database,
  ExternalLink,
  Info,
  Radar,
  RefreshCw,
  Save,
  Search,
  ShieldCheck,
  Video,
  X,
  Zap,
} from "lucide-react";
import toast from "react-hot-toast";
import { reportsApi, vlmApi, ragApi } from "@/lib/api";
import type { RagSource } from "@/types";

const INSPECTION_SCENARIOS = [
  { title: "外觀與管線異常掃描", detail: "漏油、漏水、鬆脫、外殼變形與異常磨耗。" },
  { title: "控制面板與燈號診斷", detail: "辨識 HMI 錯誤代碼與實體警示燈狀態。" },
  { title: "內部電氣元件檢查", detail: "觀察 NFB、保險絲、接線鬆脫與燒毀痕跡。" },
  { title: "RUL / 預防維護評估", detail: "根據視覺老化跡象判讀健康分數與建議保養時機。" },
];

const CHECKLIST = [
  "確認鏡頭權限與 HTTPS / WebRTC 通道可用。",
  "選擇本次巡檢場景與目標設備，避免在同一輪混入多台設備。",
  "若需要維修建議，先完成現象拍攝，再切換到知識作業台查 SOP。",
];

type VlmStatus = {
  webui_ok: boolean;
  llm_ok: boolean;
  webui_url: string;
  llm_url: string;
  model?: string | null;
};

/** 可折疊面板 */
function Collapsible({
  title,
  kicker,
  icon,
  defaultOpen = false,
  children,
}: {
  title: string;
  kicker?: string;
  icon?: React.ReactNode;
  defaultOpen?: boolean;
  children: React.ReactNode;
}) {
  const [open, setOpen] = useState(defaultOpen);
  return (
    <div className="panel-soft rounded-[28px] overflow-hidden">
      <button
        type="button"
        onClick={() => setOpen((v) => !v)}
        className="flex w-full items-center justify-between gap-3 px-5 py-4 text-left transition-colors hover:bg-white/[0.02]"
      >
        <div className="flex items-center gap-3">
          {icon && (
            <div className="flex h-9 w-9 flex-shrink-0 items-center justify-center rounded-xl border border-white/10 bg-white/[0.04]">
              {icon}
            </div>
          )}
          <div>
            {kicker && <p className="text-[10px] uppercase tracking-[0.24em] text-slate-500">{kicker}</p>}
            <p className="mt-0.5 text-sm font-semibold text-white">{title}</p>
          </div>
        </div>
        {open
          ? <ChevronUp className="h-4 w-4 flex-shrink-0 text-slate-500" />
          : <ChevronDown className="h-4 w-4 flex-shrink-0 text-slate-500" />}
      </button>
      {open && <div className="border-t border-white/8 px-5 pb-5 pt-4">{children}</div>}
    </div>
  );
}

export default function VlmPage() {
  const [saving, setSaving] = useState(false);
  const [sessionId, setSessionId] = useState<string | null>(null);
  const [iframeKey, setIframeKey] = useState(0);
  const [status, setStatus] = useState<VlmStatus | null>(null);
  const [statusLoading, setStatusLoading] = useState(false);
  const iframeRef = useRef<HTMLIFrameElement>(null);
  const [showCompare, setShowCompare] = useState(false);
  const [compareQuery, setCompareQuery] = useState("");
  const [comparing, setComparing] = useState(false);
  const [compareResult, setCompareResult] = useState<{
    answer: string;
    sources: RagSource[];
  } | null>(null);

  const VLM_URL = process.env.NEXT_PUBLIC_VLM_WEBUI_URL ?? "http://localhost:8090";

  const loadStatus = useCallback(async () => {
    setStatusLoading(true);
    try {
      const response = await vlmApi.status();
      setStatus(response.data);
    } catch {
      setStatus({
        webui_ok: false,
        llm_ok: false,
        webui_url: VLM_URL,
        llm_url: "http://localhost:8080",
        model: null,
      });
    } finally {
      setStatusLoading(false);
    }
  }, [VLM_URL]);

  useEffect(() => { loadStatus(); }, [loadStatus]);

  const handleRefresh = async () => {
    setIframeKey((c) => c + 1);
    await loadStatus();
  };

  const handleCompare = async () => {
    if (!compareQuery.trim()) return;
    setComparing(true);
    setCompareResult(null);
    try {
      const res = await ragApi.query({ question: compareQuery, top_k: 5 });
      setCompareResult({ answer: res.data.answer, sources: res.data.sources });
    } catch (err: any) {
      toast.error(err?.response?.data?.detail ?? "知識庫比對失敗");
    } finally {
      setComparing(false);
    }
  };

  const handleSaveSession = async () => {
    setSaving(true);
    try {
      const response = await reportsApi.captureVlmSession({
        session_id: sessionId ?? `vlm-${Date.now()}`,
        source: "vlm-webui",
        captured_at: new Date().toISOString(),
      });
      setSessionId(response.data.id ?? response.data.title);
      toast.success("巡檢記錄已轉為維護報告。");
    } catch (error: any) {
      toast.error(error?.response?.data?.detail ?? "儲存失敗，請確認後端服務是否運作。");
    } finally {
      setSaving(false);
    }
  };

  return (
    <div className="space-y-4">

      {/* ══════════════════════════════════════════════════════════
          1. 現場影像主畫面（最上方、全寬、最大化）
          ══════════════════════════════════════════════════════════ */}
      <section className="panel-soft rounded-[32px] p-4 sm:p-5">
        {/* 標題列 + 操作按鈕 */}
        <div className="flex flex-col gap-3 border-b border-white/8 pb-4 sm:flex-row sm:items-center sm:justify-between">
          <div className="flex items-center gap-3">
            <div className="flex h-10 w-10 flex-shrink-0 items-center justify-center rounded-2xl border border-brand-400/30 bg-brand-500/15">
              <Camera className="h-4.5 w-4.5 text-brand-300" />
            </div>
            <div>
              <p className="text-[10px] uppercase tracking-[0.24em] text-slate-500">Live Inspection Surface</p>
              <h1 className="mt-0.5 text-xl font-semibold text-white">現場影像與推論畫面</h1>
            </div>
            {/* 狀態 pills */}
            <div className="ml-2 hidden items-center gap-2 sm:flex">
              <StatusDot ok={status?.webui_ok ?? false} loading={statusLoading} label="WebUI" />
              <StatusDot ok={status?.llm_ok ?? false} loading={statusLoading} label="引擎" />
              {sessionId && <span className="status-pill status-pill-ok">報告已建立</span>}
            </div>
          </div>

          <div className="flex flex-wrap gap-2">
            <button onClick={handleRefresh} className="secondary-button" disabled={statusLoading}>
              <RefreshCw className={`h-4 w-4 ${statusLoading ? "animate-spin" : ""}`} />
              重載
            </button>
            <a href={VLM_URL} target="_blank" rel="noopener noreferrer" className="secondary-button">
              <ExternalLink className="h-4 w-4" />
              獨立視窗
            </a>
            <button onClick={handleSaveSession} disabled={saving} className="primary-button">
              <Save className="h-4 w-4" />
              {saving ? "轉換中..." : "儲存為報告"}
            </button>
            <button
              onClick={() => setShowCompare((v) => !v)}
              className={`secondary-button ${showCompare ? "border-brand-500/50 bg-brand-500/15 text-brand-200" : ""}`}
            >
              <Database className="h-4 w-4" />
              知識庫比對
            </button>
          </div>
        </div>

        {/* ── iframe 主畫面（全寬，高度自適應） ── */}
        <div
          className="mt-4 overflow-hidden rounded-[28px] border border-white/8 bg-slate-950/70"
          style={{ height: "clamp(500px, calc(100vh - 280px), 900px)" }}
        >
          <iframe
            key={iframeKey}
            ref={iframeRef}
            src={VLM_URL}
            className="h-full w-full border-0"
            title="live-vlm-webui"
            allow="camera; microphone; autoplay; clipboard-write"
            sandbox="allow-same-origin allow-scripts allow-forms allow-popups allow-modals allow-downloads allow-pointer-lock"
          />
        </div>

        {/* ── 知識庫比對折疊面板 ── */}
        {showCompare && (
          <div className="mt-4 rounded-[28px] border border-white/10 bg-slate-950/60 p-5">
            <div className="flex items-center justify-between gap-3 border-b border-white/8 pb-4">
              <div>
                <p className="text-[10px] uppercase tracking-[0.24em] text-slate-500">Knowledge Compare</p>
                <h3 className="mt-1 text-base font-semibold text-white">知識庫比對</h3>
              </div>
              <button
                onClick={() => { setShowCompare(false); setCompareResult(null); }}
                className="ghost-button h-8 w-8 rounded-xl px-0 text-slate-500"
              >
                <X className="h-4 w-4" />
              </button>
            </div>

            <div className="mt-4 flex gap-3">
              <input
                type="text"
                value={compareQuery}
                onChange={(e) => setCompareQuery(e.target.value)}
                onKeyDown={(e) => e.key === "Enter" && handleCompare()}
                placeholder="描述異常現象，查詢知識庫中的相關維修資訊…"
                className="flex-1 rounded-[16px] border border-white/10 bg-slate-950/50 px-4 py-3 text-sm text-white placeholder-slate-600 outline-none transition-colors focus:border-brand-500/50 focus:ring-2 focus:ring-brand-500/20"
              />
              <button
                onClick={handleCompare}
                disabled={comparing || !compareQuery.trim()}
                className="primary-button whitespace-nowrap"
              >
                {comparing ? <RefreshCw className="h-4 w-4 animate-spin" /> : <Search className="h-4 w-4" />}
                {comparing ? "比對中…" : "比對"}
              </button>
            </div>

            {compareResult && (
              <div className="mt-4 space-y-3">
                <div className="rounded-[20px] border border-white/8 bg-white/[0.03] p-4">
                  <p className="text-[10px] font-semibold uppercase tracking-[0.22em] text-slate-500">知識庫回應</p>
                  <div className="mt-3 whitespace-pre-wrap text-sm leading-7 text-slate-200">
                    {compareResult.answer}
                  </div>
                </div>
                {compareResult.sources.length > 0 && (
                  <div className="space-y-2">
                    <p className="text-[10px] font-semibold uppercase tracking-[0.22em] text-slate-500">參考來源</p>
                    {compareResult.sources.map((s, i) => (
                      <div key={i} className="flex items-center justify-between gap-3 rounded-[16px] border border-white/8 bg-slate-950/30 px-4 py-2.5">
                        <p className="truncate text-sm text-slate-300">{s.filename}</p>
                        {s.score != null && (
                          <span className="table-chip whitespace-nowrap">{(s.score * 100).toFixed(0)}%</span>
                        )}
                      </div>
                    ))}
                  </div>
                )}
              </div>
            )}
          </div>
        )}
      </section>

      {/* ══════════════════════════════════════════════════════════
          2. 次要資訊：可折疊區塊（預設收合）
          ══════════════════════════════════════════════════════════ */}
      <section className="grid gap-4 lg:grid-cols-3">
        {/* 系統狀態 */}
        <Collapsible
          kicker="System"
          title="推論引擎狀態"
          icon={<Radar className="h-4 w-4 text-slate-300" />}
          defaultOpen={false}
        >
          <div className="grid grid-cols-2 gap-3">
            <StatusTile label="VLM WebUI" statusLabel={status?.webui_ok ? "Ready" : "Offline"} value={status?.webui_ok ? "Online" : "Offline"} detail={status?.webui_url ?? VLM_URL} tone={status?.webui_ok ? "status-pill-ok" : "status-pill-danger"} />
            <StatusTile label="推論引擎" statusLabel={status?.llm_ok ? "Ready" : "Offline"} value={status?.llm_ok ? "Gemma Ready" : "Engine Offline"} detail={status?.model ?? "Gemma 4 E4B"} tone={status?.llm_ok ? "status-pill-ok" : "status-pill-danger"} />
            <StatusTile label="模型端點" statusLabel="API" value="http://llama-cpp:8080" detail="OpenAI 相容 API" tone="status-pill-warn" />
            <StatusTile label="報告儲存" statusLabel={sessionId ? "Ready" : "Standby"} value={sessionId ? "報告已建立" : "等待巡檢結果"} detail="支援轉出維護報告" tone={sessionId ? "status-pill-ok" : "status-pill-warn"} />
          </div>
        </Collapsible>

        {/* 巡檢前確認 */}
        <Collapsible
          kicker="Preflight"
          title="巡檢前確認"
          icon={<ShieldCheck className="h-4 w-4 text-emerald-300" />}
          defaultOpen={false}
        >
          <div className="space-y-2.5">
            {CHECKLIST.map((item) => (
              <div key={item} className="flex items-start gap-3 rounded-[16px] border border-white/8 bg-slate-950/30 px-3.5 py-3">
                <CheckCircle2 className="mt-0.5 h-4 w-4 flex-shrink-0 text-emerald-300" />
                <p className="text-xs leading-5 text-slate-300">{item}</p>
              </div>
            ))}
          </div>
        </Collapsible>

        {/* 建議巡檢場景 */}
        <Collapsible
          kicker="Inspection Scenarios"
          title="建議巡檢場景"
          icon={<Info className="h-4 w-4 text-brand-300" />}
          defaultOpen={false}
        >
          <div className="space-y-2.5">
            {INSPECTION_SCENARIOS.map((s, i) => (
              <div key={s.title} className="rounded-[18px] border border-white/8 bg-white/[0.03] p-3.5">
                <div className="flex items-center gap-2.5">
                  <span className="table-chip">0{i + 1}</span>
                  <p className="text-xs font-semibold text-white">{s.title}</p>
                </div>
                <p className="mt-1.5 text-xs leading-5 text-slate-400">{s.detail}</p>
              </div>
            ))}
            <div className="rounded-[18px] border border-amber-400/15 bg-amber-500/8 p-3.5">
              <div className="flex items-start gap-2.5">
                <Zap className="mt-0.5 h-3.5 w-3.5 flex-shrink-0 text-amber-300" />
                <p className="text-xs leading-5 text-slate-300">
                  拍攝異常 → 點「儲存為報告」→ 點「知識庫比對」輸入現象描述，3 步完成現場診斷記錄。
                </p>
              </div>
            </div>
          </div>
        </Collapsible>
      </section>
    </div>
  );
}

function StatusDot({ ok, loading, label }: { ok: boolean; loading: boolean; label: string }) {
  return (
    <div className="flex items-center gap-1.5 rounded-full border border-white/8 bg-white/[0.04] px-2.5 py-1">
      <span className={`h-1.5 w-1.5 rounded-full ${loading ? "animate-pulse bg-slate-500" : ok ? "bg-emerald-400" : "bg-red-500"}`} />
      <span className="text-[11px] text-slate-400">{label}</span>
    </div>
  );
}

function StatusTile({ label, statusLabel, value, detail, tone }: {
  label: string; statusLabel: string; value: string; detail: string; tone: string;
}) {
  return (
    <div className="rounded-[20px] border border-white/10 bg-white/[0.04] p-4">
      <div className="flex items-center justify-between gap-2">
        <p className="text-[10px] uppercase tracking-[0.2em] text-slate-500">{label}</p>
        <span className={`status-pill ${tone}`}>{statusLabel}</span>
      </div>
      <p className="mt-3 break-all text-sm font-semibold text-white">{value}</p>
      <p className="mt-1 text-xs text-slate-400">{detail}</p>
    </div>
  );
}
