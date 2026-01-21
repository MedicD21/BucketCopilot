import SwiftUI
import SwiftData

struct BucketsListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Bucket.priority) private var buckets: [Bucket]
    @State private var showingAddBucket = false
    @State private var selectedBucket: Bucket?
    
    var body: some View {
        NavigationView {
            Group {
                if buckets.isEmpty {
                    EmptyBucketsView(onAddBucket: { showingAddBucket = true })
                } else {
                    List {
                        ForEach(buckets) { bucket in
                            BucketRow(bucket: bucket)
                                .onTapGesture {
                                    selectedBucket = bucket
                                }
                        }
                        .onDelete(perform: deleteBuckets)
                    }
                }
            }
            .navigationTitle("Buckets")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingAddBucket = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddBucket) {
                AddBucketView()
            }
            .sheet(item: $selectedBucket) { bucket in
                BucketDetailView(bucket: bucket)
            }
        }
    }
    
    private func deleteBuckets(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                modelContext.delete(buckets[index])
            }
        }
    }
}

struct BucketRow: View {
    let bucket: Bucket
    @Environment(\.modelContext) private var modelContext
    @State private var state: BucketState?
    
    var body: some View {
        HStack {
            Image(systemName: bucket.icon)
                .foregroundColor(Color(hex: bucket.color))
                .frame(width: 32)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(bucket.name)
                    .font(.headline)
                
                if let state = state {
                    Text("Available: \(formatCurrency(state.available))")
                        .font(.caption)
                        .foregroundColor(state.isOverspent ? .red : .secondary)
                } else {
                    Text("Loading...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
        }
        .onAppear {
            loadState()
        }
    }
    
    private func loadState() {
        let service = BucketLedgerService(modelContext: modelContext)
        Task {
            do {
                let bucketState = try service.getBucketState(bucket: bucket)
                await MainActor.run {
                    state = bucketState
                }
            } catch {
                print("Error loading bucket state: \(error)")
            }
        }
    }
    
    private func formatCurrency(_ amount: Decimal) -> String {
        NumberFormatter.currency.string(from: amount as NSDecimalNumber) ?? "$0.00"
    }
}

struct EmptyBucketsView: View {
    let onAddBucket: () -> Void
    
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "folder.badge.plus")
                .font(.system(size: 64))
                .foregroundColor(.secondary)
            
            Text("No Buckets Yet")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Create your first budget bucket to get started")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button(action: onAddBucket) {
                Label("Create Bucket", systemImage: "plus.circle.fill")
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
        }
        .padding()
    }
}

// Placeholder views - to be implemented
struct AddBucketView: View {
    var body: some View {
        Text("Add Bucket View - Coming soon")
    }
}

struct BucketDetailView: View {
    let bucket: Bucket
    
    var body: some View {
        Text("Bucket Detail View - Coming soon")
    }
}
