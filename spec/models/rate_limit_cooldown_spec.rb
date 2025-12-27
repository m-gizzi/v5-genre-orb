# frozen_string_literal: true

require 'rails_helper'

RSpec.describe RateLimitCooldown do
  describe '.find_in_progress' do
    let!(:active_cooldown) { create(:rate_limit_cooldown, :in_progress, endpoint: 'spotify:playlists') }

    before do
      create(:rate_limit_cooldown, :expired, endpoint: 'spotify:tracks')
    end

    it 'returns active cooldown for endpoint' do
      expect(described_class.find_in_progress('spotify:playlists')).to eq(active_cooldown)
    end

    it 'returns nil for expired cooldown' do
      expect(described_class.find_in_progress('spotify:tracks')).to be_nil
    end

    it 'returns nil when no cooldown exists' do
      expect(described_class.find_in_progress('spotify:artists')).to be_nil
    end
  end

  describe '.set_cooldown!' do
    let(:endpoint) { 'spotify:playlists' }
    let(:retry_after) { 60 }

    context 'when cooldown does not exist' do
      it 'creates new cooldown' do
        expect do
          described_class.set_cooldown!(endpoint, retry_after)
        end.to change(described_class, :count).by(1)
      end

      it 'sets endpoint' do
        cooldown = described_class.set_cooldown!(endpoint, retry_after)
        expect(cooldown.endpoint).to eq(endpoint)
      end

      it 'sets retry_after_seconds' do
        cooldown = described_class.set_cooldown!(endpoint, retry_after)
        expect(cooldown.retry_after_seconds).to eq(retry_after)
      end

      it 'sets expires_at based on retry_after' do
        freeze_time do
          expected_expiry = Time.current + retry_after.seconds
          cooldown = described_class.set_cooldown!(endpoint, retry_after)
          expect(cooldown.expires_at).to be_within(1.second).of(expected_expiry)
        end
      end
    end

    context 'when cooldown already exists' do
      let!(:existing_cooldown) do
        create(:rate_limit_cooldown, endpoint: endpoint, expires_at: 1.minute.from_now, retry_after_seconds: 60)
      end

      it 'does not create duplicate cooldown' do
        expect do
          described_class.set_cooldown!(endpoint, retry_after)
        end.not_to change(described_class, :count)
      end

      context 'when new expiry is later than existing' do
        it 'extends the cooldown' do
          freeze_time do
            new_retry_after = 300
            expected_expiry = Time.current + new_retry_after.seconds

            described_class.set_cooldown!(endpoint, new_retry_after)

            expect(existing_cooldown.reload.expires_at).to be_within(1.second).of(expected_expiry)
          end
        end

        it 'updates retry_after_seconds' do
          new_retry_after = 300
          described_class.set_cooldown!(endpoint, new_retry_after)

          expect(existing_cooldown.reload.retry_after_seconds).to eq(new_retry_after)
        end
      end

      context 'when new expiry is earlier than existing' do
        it 'does not shorten the cooldown' do
          original_expiry = existing_cooldown.expires_at

          freeze_time do
            new_retry_after = 30
            described_class.set_cooldown!(endpoint, new_retry_after)

            expect(existing_cooldown.reload.expires_at).to be_within(1.second).of(original_expiry)
          end
        end
      end
    end
  end

  describe '.cleanup_expired!' do
    let!(:first_active_cooldown) { create(:rate_limit_cooldown, :in_progress) }
    let!(:second_active_cooldown) { create(:rate_limit_cooldown, :in_progress, endpoint: 'spotify:tracks') }

    before do
      create(:rate_limit_cooldown, :expired, endpoint: 'spotify:artists')
      create(:rate_limit_cooldown, :expired, endpoint: 'spotify:albums')
    end

    it 'deletes all expired cooldowns' do
      expect { described_class.cleanup_expired! }
        .to change { described_class.expired.count }.from(2).to(0)
    end

    it 'does not delete active cooldowns' do
      described_class.cleanup_expired!

      expect(described_class.in_progress).to contain_exactly(first_active_cooldown, second_active_cooldown)
    end

    it 'returns number of deleted records' do
      expect(described_class.cleanup_expired!).to eq(2)
    end
  end

  describe '#in_progress?' do
    it 'returns true when expires_at is in the future' do
      cooldown = build(:rate_limit_cooldown, expires_at: 5.minutes.from_now)
      expect(cooldown).to be_in_progress
    end

    it 'returns false when expires_at is in the past' do
      cooldown = build(:rate_limit_cooldown, expires_at: 5.minutes.ago)
      expect(cooldown).not_to be_in_progress
    end

    it 'returns false when expires_at is now' do
      cooldown = build(:rate_limit_cooldown, expires_at: Time.current)
      expect(cooldown).not_to be_in_progress
    end
  end

  describe '#seconds_remaining' do
    it 'returns seconds until expiry' do
      freeze_time do
        cooldown = build(:rate_limit_cooldown, expires_at: 5.minutes.from_now)
        expect(cooldown.seconds_remaining).to eq(300)
      end
    end

    it 'returns 0 when cooldown has expired' do
      cooldown = build(:rate_limit_cooldown, expires_at: 5.minutes.ago)
      expect(cooldown.seconds_remaining).to eq(0)
    end
  end
end
