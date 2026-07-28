"use client";

import { useState } from "react";
import { Trash2, X } from "lucide-react";
import { updateTask, deleteTask, addTaskComment } from "@/app/projects/actions";
import { formatRelativeDate } from "@/lib/utils";
import type { ProjectPerson, ProjectTask } from "@/lib/types";

function formatWhen(iso: string) {
  return new Date(iso).toLocaleString("en-PK", {
    day: "2-digit",
    month: "short",
    hour: "2-digit",
    minute: "2-digit",
  });
}

export function TaskDetailModal({
  task,
  projectId,
  members,
  onClose,
}: {
  task: ProjectTask;
  projectId: string;
  members: ProjectPerson[];
  onClose: () => void;
}) {
  const [confirmingDelete, setConfirmingDelete] = useState(false);
  const overdue =
    task.status !== "done" && !!task.dueDate && formatRelativeDate(task.dueDate).daysUntil < 0;

  return (
    <div
      className="fixed inset-0 z-[60] flex items-center justify-center bg-black/50 p-4"
      onClick={onClose}
    >
      <div
        className="max-h-[85vh] w-full max-w-lg overflow-y-auto border border-outline-variant bg-surface p-6"
        onClick={(e) => e.stopPropagation()}
      >
        <div className="flex items-start justify-between gap-3">
          <div>
            <h2 className="text-[16px] font-semibold text-on-surface">{task.title}</h2>
            <p className="mt-1 font-mono-data text-[10px] uppercase tracking-wider text-on-surface-variant">
              {task.status.replace("_", " ")}
              {task.dueDate && (
                <span className={overdue ? "ml-2 text-error" : "ml-2"}>
                  · {formatRelativeDate(task.dueDate).label}
                </span>
              )}
            </p>
          </div>
          <button
            onClick={onClose}
            aria-label="Close"
            className="text-on-surface-variant hover:text-on-surface"
          >
            <X size={18} />
          </button>
        </div>

        {task.description && (
          <p className="mt-3 text-[13px] leading-6 text-on-surface-variant">{task.description}</p>
        )}

        <form action={updateTask} className="mt-4 space-y-3 border-t border-outline-variant pt-4">
          <input type="hidden" name="taskId" value={task.id} />
          <input type="hidden" name="projectId" value={projectId} />

          <div className="grid grid-cols-2 gap-3">
            <div>
              <label className="mb-1 block font-mono-data text-[10px] uppercase tracking-wider text-on-surface-variant">
                Priority
              </label>
              <select
                name="priority"
                defaultValue={task.priority}
                className="w-full border border-outline-variant bg-background px-2 py-1.5 font-mono-data text-[12px] focus:border-primary focus:outline-none"
              >
                <option value="low">Low</option>
                <option value="medium">Medium</option>
                <option value="high">High</option>
                <option value="urgent">Urgent</option>
              </select>
            </div>
            <div>
              <label className="mb-1 block font-mono-data text-[10px] uppercase tracking-wider text-on-surface-variant">
                Due date
              </label>
              <input
                type="date"
                name="dueDate"
                defaultValue={task.dueDate ?? ""}
                className="w-full border border-outline-variant bg-background px-2 py-1.5 font-mono-data text-[12px] focus:border-primary focus:outline-none"
              />
            </div>
          </div>

          <div>
            <label className="mb-1 block font-mono-data text-[10px] uppercase tracking-wider text-on-surface-variant">
              Assignees
            </label>
            <div className="flex flex-wrap gap-2">
              {members.map((m) => (
                <label
                  key={m.id}
                  className="flex items-center gap-1.5 border border-outline-variant px-2 py-1 text-[11px] text-on-surface-variant"
                >
                  <input
                    type="checkbox"
                    name="assigneeIds"
                    value={m.id}
                    defaultChecked={task.assignees.some((a) => a.id === m.id)}
                  />
                  {m.fullName ?? "Unnamed"}
                </label>
              ))}
              {members.length === 0 && (
                <p className="text-[11px] text-on-surface-variant/60">No project members yet.</p>
              )}
            </div>
          </div>

          <button
            type="submit"
            className="w-full bg-primary px-4 py-2 font-mono-data text-[11px] uppercase tracking-wider text-on-primary transition hover:brightness-110 active:scale-95"
          >
            Save changes
          </button>
        </form>

        <div className="mt-5 border-t border-outline-variant pt-4">
          <p className="font-mono-data text-[11px] uppercase tracking-wider text-on-surface-variant">
            Comments
          </p>
          <div className="mt-2 max-h-40 space-y-2 overflow-y-auto">
            {task.comments.length === 0 && (
              <p className="text-[12px] text-on-surface-variant/60">No comments yet.</p>
            )}
            {task.comments.map((c) => (
              <div key={c.id} className="border-l-2 border-outline-variant pl-2">
                <div className="flex items-baseline gap-2">
                  <span className="text-[12px] font-semibold text-on-surface">
                    {c.authorName ?? "Someone"}
                  </span>
                  <span className="font-mono-data text-[10px] text-on-surface-variant/60">
                    {formatWhen(c.createdAt)}
                  </span>
                </div>
                <p className="text-[12px] text-on-surface-variant">{c.body}</p>
              </div>
            ))}
          </div>

          <form action={addTaskComment} className="mt-3 flex gap-2">
            <input type="hidden" name="taskId" value={task.id} />
            <input type="hidden" name="projectId" value={projectId} />
            <input
              name="body"
              required
              placeholder="Add a comment…"
              className="flex-1 border border-outline-variant bg-background px-2 py-1.5 text-[12px] focus:border-primary focus:outline-none"
            />
            <button
              type="submit"
              className="bg-primary px-3 py-1.5 font-mono-data text-[10px] uppercase tracking-wider text-on-primary transition hover:brightness-110"
            >
              Post
            </button>
          </form>
        </div>

        <div className="mt-5 border-t border-outline-variant pt-4">
          {!confirmingDelete ? (
            <button
              onClick={() => setConfirmingDelete(true)}
              className="flex items-center gap-2 font-mono-data text-[11px] uppercase tracking-wider text-error hover:underline"
            >
              <Trash2 size={13} />
              Delete task
            </button>
          ) : (
            <form action={deleteTask} className="flex items-center gap-2">
              <input type="hidden" name="taskId" value={task.id} />
              <input type="hidden" name="projectId" value={projectId} />
              <span className="text-[11px] text-error">Delete this task permanently?</span>
              <button
                type="submit"
                className="bg-error px-2 py-1 font-mono-data text-[10px] uppercase tracking-wider text-white transition hover:brightness-110"
              >
                Confirm
              </button>
              <button
                type="button"
                onClick={() => setConfirmingDelete(false)}
                className="text-[10px] text-on-surface-variant hover:text-on-surface"
              >
                Cancel
              </button>
            </form>
          )}
        </div>
      </div>
    </div>
  );
}
