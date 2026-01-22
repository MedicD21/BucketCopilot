import SwiftUI
import SwiftData

struct RulesListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \FundingRule.priority) private var rules: [FundingRule]
    @State private var showingAddRule = false
    @State private var showingPreview = false
    
    var body: some View {
        NavigationView {
            Group {
                if rules.isEmpty {
                    EmptyRulesView(onAddRule: { showingAddRule = true })
                } else {
                    List {
                        Section {
                            ForEach(rules) { rule in
                                RuleRow(rule: rule)
                            }
                            .onDelete(perform: deleteRules)
                        } header: {
                            HStack {
                                Text("Funding Rules")
                                Spacer()
                                Button(action: { showingPreview = true }) {
                                    Label("Preview", systemImage: "eye")
                                        .font(.caption)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Rules")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingAddRule = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddRule) {
                AddRuleView()
            }
            .sheet(isPresented: $showingPreview) {
                RulePreviewView()
            }
        }
    }
    
    private func deleteRules(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                modelContext.delete(rules[index])
            }
        }
    }
}

struct RuleRow: View {
    let rule: FundingRule
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(rule.name)
                    .font(.headline)
                
                Spacer()
                
                if rule.enabled {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                } else {
                    Image(systemName: "circle")
                        .foregroundColor(.gray)
                }
            }
            
            Text("Priority: \(rule.priority) • \(rule.triggerTypeEnum.rawValue)")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text("\(rule.actions.count) action(s)")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

struct EmptyRulesView: View {
    let onAddRule: () -> Void
    
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "gearshape.2")
                .font(.system(size: 64))
                .foregroundColor(.secondary)
            
            Text("No Funding Rules")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Create rules to automatically allocate funds to buckets")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button(action: onAddRule) {
                Label("Create Rule", systemImage: "plus.circle.fill")
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
        }
        .padding()
    }
}

struct AddRuleView: View {
    var body: some View {
        Text("Add Rule View - Coming soon")
    }
}

struct RulePreviewView: View {
    var body: some View {
        Text("Rule Preview View - Coming soon")
    }
}
