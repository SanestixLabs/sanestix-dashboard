import { Card, CardDescription, CardTitle } from "@/components/ui/card";
import { addProjectMember, removeProjectMember } from "@/app/projects/actions";
import type { ProjectPerson } from "@/lib/types";

export function MemberPicker({
  projectId,
  members,
  everyone,
}: {
  projectId: string;
  members: ProjectPerson[];
  everyone: ProjectPerson[];
}) {
  const memberIds = new Set(members.map((m) => m.id));
  const available = everyone.filter((p) => !memberIds.has(p.id));

  return (
    <Card className="p-6">
      <CardTitle>Team</CardTitle>
      <CardDescription>Who&apos;s assigned to this project.</CardDescription>

      <div className="mt-4 space-y-2">
        {members.length === 0 && (
          <p className="text-[12px] text-on-surface-variant/60">No one added yet.</p>
        )}
        {members.map((m) => (
          <div
            key={m.id}
            className="flex items-center justify-between border border-outline-variant bg-background px-3 py-2"
          >
            <span className="text-[12px] text-on-surface">{m.fullName ?? "Unnamed"}</span>
            <form action={removeProjectMember}>
              <input type="hidden" name="projectId" value={projectId} />
              <input type="hidden" name="memberId" value={m.id} />
              <button
                type="submit"
                className="font-mono-data text-[10px] uppercase tracking-wider text-on-surface-variant hover:text-error"
              >
                Remove
              </button>
            </form>
          </div>
        ))}
      </div>

      {available.length > 0 && (
        <form action={addProjectMember} className="mt-4 flex gap-2 border-t border-outline-variant pt-4">
          <input type="hidden" name="projectId" value={projectId} />
          <select
            name="memberId"
            required
            className="flex-1 border border-outline-variant bg-background px-2 py-2 font-mono-data text-[12px] focus:border-primary focus:outline-none"
          >
            <option value="">Add a teammate…</option>
            {available.map((p) => (
              <option key={p.id} value={p.id}>
                {p.fullName ?? "Unnamed"}
              </option>
            ))}
          </select>
          <button
            type="submit"
            className="bg-primary px-3 py-2 font-mono-data text-[11px] uppercase tracking-wider text-on-primary transition hover:brightness-110"
          >
            Add
          </button>
        </form>
      )}
    </Card>
  );
}
