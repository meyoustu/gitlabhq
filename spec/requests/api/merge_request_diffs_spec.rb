# frozen_string_literal: true

require "spec_helper"

RSpec.describe API::MergeRequestDiffs, 'MergeRequestDiffs' do
  let!(:user)          { create(:user) }
  let!(:merge_request) { create(:merge_request, importing: true) }
  let!(:project)       { merge_request.target_project }

  before do
    merge_request.merge_request_diffs.create!(head_commit_sha: '6f6d7e7ed97bb5f0054f2b1df789b39ca89b6ff9')
    merge_request.merge_request_diffs.create!(head_commit_sha: '5937ac0a7beb003549fc5fd26fc247adbce4a52e')
    project.add_maintainer(user)
  end

  describe 'GET /projects/:id/merge_requests/:merge_request_iid/versions' do
    it 'returns 200 for a valid merge request' do
      get api("/projects/#{project.id}/merge_requests/#{merge_request.iid}/versions", user)
      merge_request_diff = merge_request.merge_request_diffs.last

      expect(response).to have_gitlab_http_status(:ok)
      expect(response).to include_pagination_headers
      expect(json_response).to be_an Array
      expect(json_response.size).to eq(merge_request.merge_request_diffs.size)
      expect(json_response.first['id']).to eq(merge_request_diff.id)
      expect(json_response.first['head_commit_sha']).to eq(merge_request_diff.head_commit_sha)
    end

    it 'returns a 404 when merge_request id is used instead of the iid' do
      get api("/projects/#{project.id}/merge_requests/#{merge_request.id}/versions", user)
      expect(response).to have_gitlab_http_status(:not_found)
    end

    it 'returns a 404 when merge_request_iid not found' do
      get api("/projects/#{project.id}/merge_requests/0/versions", user)
      expect(response).to have_gitlab_http_status(:not_found)
    end

    context 'when merge request author has only guest access' do
      it_behaves_like 'rejects user from accessing merge request info' do
        let(:url) { "/projects/#{project.id}/merge_requests/#{merge_request.iid}/versions" }
      end
    end
  end

  describe 'GET /projects/:id/merge_requests/:merge_request_iid/versions/:version_id' do
    let(:merge_request_diff) { merge_request.merge_request_diffs.first }

    it 'returns a 200 for a valid merge request' do
      get api("/projects/#{project.id}/merge_requests/#{merge_request.iid}/versions/#{merge_request_diff.id}", user)

      expect(response).to have_gitlab_http_status(:ok)
      expect(json_response['id']).to eq(merge_request_diff.id)
      expect(json_response['head_commit_sha']).to eq(merge_request_diff.head_commit_sha)
      expect(json_response['diffs'].size).to eq(merge_request_diff.diffs.size)
    end

    it 'returns a 404 when merge_request id is used instead of the iid' do
      get api("/projects/#{project.id}/merge_requests/#{merge_request.id}/versions/#{merge_request_diff.id}", user)
      expect(response).to have_gitlab_http_status(:not_found)
    end

    it 'returns a 404 when merge_request version_id is not found' do
      get api("/projects/#{project.id}/merge_requests/#{merge_request.iid}/versions/0", user)
      expect(response).to have_gitlab_http_status(:not_found)
    end

    it 'returns a 404 when merge_request_iid is not found' do
      get api("/projects/#{project.id}/merge_requests/#{non_existing_record_iid}/versions/#{merge_request_diff.id}", user)
      expect(response).to have_gitlab_http_status(:not_found)
    end

    context 'when merge request author has only guest access' do
      it_behaves_like 'rejects user from accessing merge request info' do
        let(:url) { "/projects/#{project.id}/merge_requests/#{merge_request.iid}/versions/#{merge_request_diff.id}" }
      end
    end

    context 'caching merge request diffs', :use_clean_rails_redis_caching do
      it 'is performed' do
        get api("/projects/#{project.id}/merge_requests/#{merge_request.iid}/versions/#{merge_request_diff.id}", user)

        expect(Rails.cache.fetch(merge_request_diff.cache_key)).to be_present
      end

      context 'when cached_api_merge_request_version is disabled' do
        before do
          stub_feature_flags(cached_api_merge_request_version: false)
        end

        it 'is not performed' do
          get api("/projects/#{project.id}/merge_requests/#{merge_request.iid}/versions/#{merge_request_diff.id}", user)

          expect(Rails.cache.fetch(merge_request_diff.cache_key)).to be_nil
        end
      end
    end
  end
end
