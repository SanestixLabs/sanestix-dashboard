export default function FinanceLoading() {
  return (
    <div className="animate-pulse space-y-6 px-4 py-5 sm:px-6 lg:px-8 lg:py-8">
      <div className="h-7 w-56 rounded-[2px] bg-surface-container-high" />
      <div className="h-4 w-80 rounded-[2px] bg-surface-container-high" />
      <div className="h-9 w-full rounded-[2px] bg-surface-container-high" />
      <div className="grid grid-cols-1 gap-4 md:grid-cols-2 xl:grid-cols-4">
        {Array.from({ length: 4 }).map((_, i) => (
          <div key={i} className="h-24 rounded-[2px] border border-outline-variant bg-surface" />
        ))}
      </div>
      <div className="h-72 rounded-[2px] border border-outline-variant bg-surface" />
    </div>
  );
}
