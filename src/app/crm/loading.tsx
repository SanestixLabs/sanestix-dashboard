export default function CrmLoading() {
  return (
    <div className="animate-pulse space-y-6 px-4 py-5 sm:px-6 lg:px-8 lg:py-8">
      <div className="h-7 w-56 rounded-[2px] bg-surface-container-high" />
      <div className="h-4 w-80 rounded-[2px] bg-surface-container-high" />
      <div className="grid grid-cols-2 gap-4 md:grid-cols-4">
        {Array.from({ length: 4 }).map((_, i) => (
          <div key={i} className="h-20 rounded-[2px] border border-outline-variant bg-surface" />
        ))}
      </div>
      <div className="grid grid-cols-1 gap-4 lg:grid-cols-4">
        <div className="h-96 rounded-[2px] border border-outline-variant bg-surface" />
        <div className="h-96 rounded-[2px] border border-outline-variant bg-surface lg:col-span-3" />
      </div>
    </div>
  );
}
