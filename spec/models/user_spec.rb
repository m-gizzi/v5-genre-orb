# frozen_string_literal: true

require 'rails_helper'

RSpec.describe User do
  describe '#update_spotify_credentials' do
    subject(:update_credentials) { user.update_spotify_credentials(new_token, token_lifetime) }

    let(:user) { create(:user) }
    let(:new_token) { 'new_access_token_abc123' }
    let(:token_lifetime) { 3600 }
    let(:expected_expiry) { Time.current + 3600.seconds }

    before do
      travel_to Time.zone.parse('2025-12-23 10:00:00')
    end

    after do
      travel_back
    end

    it 'updates the access token' do
      expect { update_credentials }.to change { user.reload.access_token }.to(new_token)
    end

    it 'updates the token expiration time' do
      update_credentials
      expect(user.reload.token_expires_at).to be_within(1.second).of(expected_expiry)
    end

    it 'persists the changes to the database' do
      update_credentials
      user_from_db = described_class.find(user.id)
      expect(user_from_db.access_token).to eq(new_token)
      expect(user_from_db.token_expires_at).to be_within(1.second).of(expected_expiry)
    end

    context 'when token_lifetime is different' do
      let(:token_lifetime) { 7200 }
      let(:expected_expiry) { Time.current + 7200.seconds }

      it 'calculates correct expiration time' do
        update_credentials
        expect(user.reload.token_expires_at).to be_within(1.second).of(expected_expiry)
      end
    end
  end
end
