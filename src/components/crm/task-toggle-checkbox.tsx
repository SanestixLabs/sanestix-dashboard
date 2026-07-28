"use client";

export function TaskToggleCheckbox({
  action,
  taskId,
  done,
  redirectTo,
}: {
  action: (formData: FormData) => void;
  taskId: string;
  done: boolean;
  redirectTo: string;
}) {
  return (
    <form action={action}>
      <input type="hidden" name="taskId" value={taskId} />
      <input type="hidden" name="done" value={String(done)} />
      <input type="hidden" name="redirectTo" value={redirectTo} />
      <button
        type="submit"
        aria-label={done ? "Mark task not done" : "Mark task done"}
        className={
          done
            ? "flex h-4 w-4 items-center justify-center border border-success bg-success text-[10px] text-white"
            : "h-4 w-4 border border-outline-variant bg-background transition hover:border-primary"
        }
      >
        {done ? "✓" : ""}
      </button>
    </form>
  );
}
