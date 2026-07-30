"use client";

import { useState } from "react";
import {
  DndContext,
  PointerSensor,
  useDraggable,
  useDroppable,
  useSensor,
  useSensors,
  type DragEndEvent,
} from "@dnd-kit/core";
import { Plus } from "lucide-react";
import { cn, formatRelativeDate } from "@/lib/utils";
import { StatusPill } from "@/components/ui/status-pill";
import { moveTask } from "@/app/(dashboard)/projects/actions";
import { AddTaskForm } from "@/components/projects/add-task-form";
import { TaskDetailModal } from "@/components/projects/task-detail-modal";
import type { ProjectPerson, ProjectTask, TaskStatus } from "@/lib/types";

const COLUMNS: { id: TaskStatus; label: string }[] = [
  { id: "backlog", label: "Backlog" },
  { id: "todo", label: "To Do" },
  { id: "in_progress", label: "In Progress" },
  { id: "review", label: "Review" },
  { id: "done", label: "Done" },
];

const PRIORITY_TONE: Record<string, "neutral" | "primary" | "warning" | "error"> = {
  low: "neutral",
  medium: "primary",
  high: "warning",
  urgent: "error",
};

function initials(name: string | null) {
  if (!name) return "?";
  return name
    .split(" ")
    .filter(Boolean)
    .slice(0, 2)
    .map((part) => part[0]?.toUpperCase())
    .join("");
}

function TaskCard({ task, onOpen }: { task: ProjectTask; onOpen: (task: ProjectTask) => void }) {
  const { attributes, listeners, setNodeRef, transform, isDragging } = useDraggable({
    id: task.id,
  });

  const style = transform
    ? { transform: `translate3d(${transform.x}px, ${transform.y}px, 0)` }
    : undefined;

  const overdue =
    task.status !== "done" && !!task.dueDate && formatRelativeDate(task.dueDate).daysUntil < 0;

  return (
    <div
      ref={setNodeRef}
      style={style}
      {...listeners}
      {...attributes}
      onClick={() => onOpen(task)}
      role="button"
      tabIndex={0}
      className={cn(
        "cursor-grab select-none border border-outline-variant bg-surface p-3 text-left transition active:cursor-grabbing",
        isDragging ? "z-50 opacity-70 shadow-lg" : "hover:border-primary/40"
      )}
    >
      <div className="flex items-start justify-between gap-2">
        <p className="text-[13px] font-medium leading-snug text-on-surface">{task.title}</p>
        <StatusPill tone={PRIORITY_TONE[task.priority]} className="shrink-0">
          {task.priority}
        </StatusPill>
      </div>

      {task.dueDate && (
        <p
          className={cn(
            "mt-2 font-mono-data text-[10px] uppercase tracking-wider",
            overdue ? "text-error" : "text-on-surface-variant"
          )}
        >
          {formatRelativeDate(task.dueDate).label}
        </p>
      )}

      <div className="mt-2 flex items-center justify-between">
        <div className="flex flex-wrap gap-1">
          {task.assignees.map((a) => (
            <span
              key={a.id}
              title={a.fullName ?? "Unnamed"}
              className="flex h-5 w-5 items-center justify-center border border-outline-variant bg-background font-mono-data text-[9px] text-on-surface-variant"
            >
              {initials(a.fullName)}
            </span>
          ))}
        </div>
        {task.comments.length > 0 && (
          <span className="font-mono-data text-[10px] text-on-surface-variant/60">
            {task.comments.length} comment{task.comments.length === 1 ? "" : "s"}
          </span>
        )}
      </div>
    </div>
  );
}

function Column({
  id,
  label,
  tasks,
  onOpen,
}: {
  id: TaskStatus;
  label: string;
  tasks: ProjectTask[];
  onOpen: (task: ProjectTask) => void;
}) {
  const { setNodeRef, isOver } = useDroppable({ id });

  return (
    <div
      ref={setNodeRef}
      className={cn(
        "flex w-[260px] shrink-0 flex-col border border-outline-variant bg-background",
        isOver && "border-primary/60 bg-primary/[0.03]"
      )}
    >
      <div className="flex items-center justify-between border-b border-outline-variant px-3 py-2">
        <span className="font-mono-data text-[11px] uppercase tracking-wider text-on-surface-variant">
          {label}
        </span>
        <span className="font-mono-data text-[10px] text-on-surface-variant/60">
          {tasks.length}
        </span>
      </div>
      <div className="min-h-[140px] flex-1 space-y-2 overflow-y-auto p-2">
        {tasks.map((task) => (
          <TaskCard key={task.id} task={task} onOpen={onOpen} />
        ))}
        {tasks.length === 0 && (
          <p className="p-3 text-center text-[11px] text-on-surface-variant/50">No tasks</p>
        )}
      </div>
    </div>
  );
}

export function TaskBoard({
  projectId,
  initialTasks,
  members,
}: {
  projectId: string;
  initialTasks: ProjectTask[];
  members: ProjectPerson[];
}) {
  const [tasks, setTasks] = useState(initialTasks);
  const [activeTask, setActiveTask] = useState<ProjectTask | null>(null);
  const [addingTask, setAddingTask] = useState(false);

  // Server actions revalidate the page instead of redirecting (so the
  // board and any open task panel can update in place). When a fresh
  // `initialTasks` comes down from the server, sync local state from it —
  // computed during render (not in an effect) per React's guidance on
  // adjusting state from changed props.
  const [syncedTasks, setSyncedTasks] = useState(initialTasks);
  if (initialTasks !== syncedTasks) {
    setSyncedTasks(initialTasks);
    setTasks(initialTasks);
    setActiveTask((prev) => (prev ? initialTasks.find((t) => t.id === prev.id) ?? null : null));
  }

  const sensors = useSensors(
    useSensor(PointerSensor, { activationConstraint: { distance: 6 } })
  );

  function handleDragEnd(event: DragEndEvent) {
    const { active, over } = event;
    if (!over) return;

    const taskId = String(active.id);
    const newStatus = over.id as TaskStatus;
    const task = tasks.find((t) => t.id === taskId);
    if (!task || task.status === newStatus) return;

    const updated = tasks.map((t) => (t.id === taskId ? { ...t, status: newStatus } : t));
    setTasks(updated);

    const destinationIds = updated.filter((t) => t.status === newStatus).map((t) => t.id);
    void moveTask(taskId, projectId, newStatus, destinationIds);
  }

  return (
    <div>
      <div className="mb-3 flex items-center justify-between">
        <p className="font-mono-data text-[11px] uppercase tracking-wider text-on-surface-variant">
          Drag a card to change its status
        </p>
        <button
          onClick={() => setAddingTask(true)}
          className="flex items-center gap-1.5 bg-primary px-3 py-1.5 font-mono-data text-[11px] uppercase tracking-wider text-on-primary transition hover:brightness-110 active:scale-95"
        >
          <Plus size={13} />
          Add task
        </button>
      </div>

      <DndContext sensors={sensors} onDragEnd={handleDragEnd}>
        <div className="flex gap-3 overflow-x-auto pb-2">
          {COLUMNS.map((col) => (
            <Column
              key={col.id}
              id={col.id}
              label={col.label}
              tasks={tasks.filter((t) => t.status === col.id)}
              onOpen={setActiveTask}
            />
          ))}
        </div>
      </DndContext>

      {activeTask && (
        <TaskDetailModal
          task={activeTask}
          projectId={projectId}
          members={members}
          onClose={() => setActiveTask(null)}
        />
      )}

      {addingTask && (
        <AddTaskForm projectId={projectId} members={members} onClose={() => setAddingTask(false)} />
      )}
    </div>
  );
}
