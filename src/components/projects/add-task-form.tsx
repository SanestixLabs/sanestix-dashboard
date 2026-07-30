"use client";

import { X } from "lucide-react";
import { addTask } from "@/app/(dashboard)/projects/actions";
import { TASK_LABELS, type ProjectPerson } from "@/lib/types";

export function AddTaskForm({
  projectId,
  members,
  onClose,
}: {
  projectId: string;
  members: ProjectPerson[];
  onClose: () => void;
}) {
  return (
    <div
      className="fixed inset-0 z-[60] flex items-center justify-center bg-black/50 p-4"
      onClick={onClose}
    >
      <div
        className="max-h-[85vh] w-full max-w-md overflow-y-auto border border-outline-variant bg-surface p-6"
        onClick={(e) => e.stopPropagation()}
      >
        <div className="flex items-start justify-between gap-3">
          <h2 className="text-[16px] font-semibold text-on-surface">New task</h2>
          <button
            onClick={onClose}
            aria-label="Close"
            className="text-on-surface-variant hover:text-on-surface"
          >
            <X size={18} />
          </button>
        </div>

        <form action={addTask} className="mt-4 space-y-3">
          <input type="hidden" name="projectId" value={projectId} />

          <div>
            <label className="mb-1 block font-mono-data text-[11px] uppercase tracking-wider text-on-surface-variant">
              Title
            </label>
            <input
              type="text"
              name="title"
              required
              autoFocus
              className="w-full border border-outline-variant bg-background px-3 py-2 font-mono-data text-[13px] focus:border-primary focus:outline-none"
              placeholder="e.g. Wire up payment webhook"
            />
          </div>

          <div>
            <label className="mb-1 block font-mono-data text-[11px] uppercase tracking-wider text-on-surface-variant">
              Description
            </label>
            <textarea
              name="description"
              rows={3}
              className="w-full border border-outline-variant bg-background px-3 py-2 font-mono-data text-[13px] focus:border-primary focus:outline-none"
              placeholder="Optional"
            />
          </div>

          <div className="grid grid-cols-2 gap-3">
            <div>
              <label className="mb-1 block font-mono-data text-[11px] uppercase tracking-wider text-on-surface-variant">
                Priority
              </label>
              <select
                name="priority"
                defaultValue="medium"
                className="w-full border border-outline-variant bg-background px-3 py-2 font-mono-data text-[13px] focus:border-primary focus:outline-none"
              >
                <option value="low">Low</option>
                <option value="medium">Medium</option>
                <option value="high">High</option>
                <option value="urgent">Urgent</option>
              </select>
            </div>
            <div>
              <label className="mb-1 block font-mono-data text-[11px] uppercase tracking-wider text-on-surface-variant">
                Due date
              </label>
              <input
                type="date"
                name="dueDate"
                className="w-full border border-outline-variant bg-background px-3 py-2 font-mono-data text-[13px] focus:border-primary focus:outline-none"
              />
            </div>
          </div>

          <div>
            <label className="mb-1 block font-mono-data text-[11px] uppercase tracking-wider text-on-surface-variant">
              Labels
            </label>
            <div className="flex flex-wrap gap-2">
              {TASK_LABELS.map((label) => (
                <label
                  key={label}
                  className="flex items-center gap-1.5 border border-outline-variant px-2 py-1 text-[11px] text-on-surface-variant"
                >
                  <input type="checkbox" name="labels" value={label} />
                  {label}
                </label>
              ))}
            </div>
          </div>

          <div>
            <label className="mb-1 block font-mono-data text-[11px] uppercase tracking-wider text-on-surface-variant">
              Assignees
            </label>
            <div className="flex flex-wrap gap-2">
              {members.map((m) => (
                <label
                  key={m.id}
                  className="flex items-center gap-1.5 border border-outline-variant px-2 py-1 text-[11px] text-on-surface-variant"
                >
                  <input type="checkbox" name="assigneeIds" value={m.id} />
                  {m.fullName ?? "Unnamed"}
                </label>
              ))}
              {members.length === 0 && (
                <p className="text-[11px] text-on-surface-variant/60">
                  Add project members first to assign tasks.
                </p>
              )}
            </div>
          </div>

          <button
            type="submit"
            className="w-full bg-primary px-4 py-2.5 font-mono-data text-[11px] font-medium uppercase tracking-wider text-on-primary transition hover:brightness-110 active:scale-95"
          >
            Add task
          </button>
        </form>
      </div>
    </div>
  );
}
