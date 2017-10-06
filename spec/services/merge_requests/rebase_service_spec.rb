require 'spec_helper'

describe MergeRequests::RebaseService do
  let(:user) { create(:user) }
  let(:merge_request) do
    create(:merge_request,
           source_branch: 'feature_conflict',
           target_branch: 'master')
  end
  let(:project) { merge_request.project }

  subject(:service) { described_class.new(project, user, {}) }

  before do
    project.team << [user, :master]
  end

  describe '#execute' do
    context 'when another rebase is already in progress' do
      before do
        allow(merge_request).to receive(:rebase_in_progress?).and_return(true)
      end

      it 'saves the error message' do
        subject.execute(merge_request)

        expect(merge_request.reload.merge_error).to eq 'Rebase task canceled: Another rebase is already in progress'
      end

      it 'returns an error' do
        expect(service.execute(merge_request)).to match(status: :error,
                                                        message: 'Failed to rebase. Should be done manually')
      end
    end

    context 'when unexpected error occurs' do
      before do
        allow(service).to receive(:run_git_command).and_raise('Something went wrong')
      end

      it 'saves the error message' do
        subject.execute(merge_request)

        expect(merge_request.reload.merge_error).to eq 'Something went wrong'
      end

      it 'returns an error' do
        expect(service.execute(merge_request)).to match(status: :error,
                                                        message: 'Failed to rebase. Should be done manually')
      end
    end

    context 'with git command failure' do
      before do
        allow(service).to receive(:popen).and_return(['Something went wrong', 1])
      end

      it 'saves the error message' do
        subject.execute(merge_request)

        expect(merge_request.reload.merge_error).to eq 'Something went wrong'
      end

      it 'returns an error' do
        expect(service.execute(merge_request)).to match(status: :error,
                                                        message: 'Failed to rebase. Should be done manually')
      end
    end

    context 'valid params' do
      before do
        service.execute(merge_request)
      end

      it 'rebases source branch' do
        parent_sha = merge_request.source_project.repository.commit(merge_request.source_branch).parents.first.sha
        target_branch_sha = merge_request.target_project.repository.commit(merge_request.target_branch).sha
        expect(parent_sha).to eq(target_branch_sha)
      end

      it 'records the new SHA on the merge request' do
        head_sha = merge_request.source_project.repository.commit(merge_request.source_branch).sha
        expect(merge_request.reload.rebase_commit_sha).to eq(head_sha)
      end

      it 'logs correct author and commiter' do
        head_commit = merge_request.source_project.repository.commit(merge_request.source_branch)

        expect(head_commit.author_email).to eq('dmitriy.zaporozhets@gmail.com')
        expect(head_commit.author_name).to eq('Dmitriy Zaporozhets')
        expect(head_commit.committer_email).to eq(user.email)
        expect(head_commit.committer_name).to eq(user.name)
      end

      context 'git commands' do
        it 'sets GL_REPOSITORY env variable when calling git commands' do
          expect_any_instance_of(described_class)
            .to receive(:run_git_command).exactly(3).with(
              anything,
              anything,
              hash_including('GL_REPOSITORY'),
              anything)

          service.execute(merge_request)
        end
      end
    end
  end
end
