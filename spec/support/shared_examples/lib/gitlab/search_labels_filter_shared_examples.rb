# frozen_string_literal: true

RSpec.shared_examples 'search results filtered by labels' do
  let_it_be(:project_label) { create(:label, project: project) }
  let_it_be(:labeled_issue) { create(:labeled_issue, labels: [project_label], project: project, title: 'foo project') }
  let_it_be(:unlabeled_issue) { create(:issue, project: project, title: 'foo unlabeled') }

  let(:filters) { { labels: [project_label.id] } }

  before do
    ::Elastic::ProcessBookkeepingService.track!(labeled_issue)
    ::Elastic::ProcessBookkeepingService.track!(unlabeled_issue)
    ensure_elasticsearch_index!
  end

  it 'filters by labels', :sidekiq_inline do
    expect(results.objects(scope)).to contain_exactly(labeled_issue)
  end
end
