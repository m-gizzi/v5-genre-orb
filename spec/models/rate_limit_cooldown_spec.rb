# frozen_string_literal: true

require 'rails_helper'

RSpec.describe RateLimitCooldown do
  describe 'scopes' do
    describe '.in_progress' do
      let!(:active_cooldown) { create(:rate_limit_cooldown, :in_progress) }
      let!(:expired_cooldown) { create(:rate_limit_cooldown, :expired, endpoint: 'spotify:tracks') }

      it 'returns only cooldowns that have not expired' do
        expect(described_class.in_progress).to contain_exactly(active_cooldown)
      end

      it 'does not include expired cooldowns' do
        expect(described_class.in_progress).not_to include(expired_cooldown)
      end
    end

    describe '.expired' do
      let!(:active_cooldown) { create(:rate_limit_cooldown, :in_progress) }
      let!(:expired_cooldown) { create(:rate_limit_cooldown, :expired, endpoint: 'spotify:tracks') }

      it 'returns only expired cooldowns' do
        expect(described_class.expired).to contain_exactly(expired_cooldown)
      end

      it 'does not include active cooldowns' do
        expect(described_class.expired).not_to include(active_cooldown)
      end
    end
  end

  describe '.in_progress_for?' do
    let!(:active_cooldown) { create(:rate_limit_cooldown, :in_progress, endpoint: 'spotify:playlists') }
    let!(:expired_cooldown) { create(:rate_limit_cooldown, :expired, endpoint: 'spotify:tracks') }

    it 'returns true when active cooldown exists for endpoint' do
      expect(described_class.in_progress_for?('spotify:playlists')).to be true
    end

    it 'returns false when cooldown is expired' do
      expect(described_class.in_progress_for?('spotify:tracks')).to be false
    end

    it 'returns false when no cooldown exists for endpoint' do
      expect(described_class.in_progress_for?('spotify:artists')).to be false
    end
  end

  describe '.find_in_progress' do
    let!(:active_cooldown) { create(:rate_limit_cooldown, :in_progress, endpoint: 'spotify:playlists') }
    let!(:expired_cooldown) { create(:rate_limit_cooldown, :expired, endpoint: 'spotify:tracks') }

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
        expect {
          described_class.set_cooldown!(endpoint, retry_after)
        }.to change(described_class, :count).by(1)
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
        expect {
          described_class.set_cooldown!(endpoint, retry_after)
        }.not_to change(described_class, :count)
      end

      context 'when new expiry is later than existing' do
        it 'extends the cooldown' do
          freeze_time do
            new_retry_after = 300 # 5 minutes
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
            new_retry_after = 30 # Shorter than existing
            described_class.set_cooldown!(endpoint, new_retry_after)

            # Should keep the longer expiry
            expect(existing_cooldown.reload.expires_at).to be_within(1.second).of(original_expiry)
          end
        end
      end
    end

    context 'thread safety' do
      it 'prevents duplicate creation when called concurrently' do
        # Simulate concurrent calls
        threads = 3.times.map do
          Thread.new { described_class.set_cooldown!(endpoint, retry_after) }
        end

        threads.each(&:join)

        # Should only create one cooldown despite concurrent calls
        expect(described_class.where(endpoint: endpoint).count).to eq(1)
      end
    end
  end

  describe '.cleanup_expired!' do
    let!(:active_cooldown1) { create(:rate_limit_cooldown, :in_progress) }
    let!(:active_cooldown2) { create(:rate_limit_cooldown, :in_progress, endpoint: 'spotify:tracks') }
    let!(:expired_cooldown1) { create(:rate_limit_cooldown, :expired, endpoint: 'spotify:artists') }
    let!(:expired_cooldown2) { create(:rate_limit_cooldown, :expired, endpoint: 'spotify:albums') }

    it 'deletes all expired cooldowns' do
      expect { described_class.cleanup_expired! }
        .to change { described_class.expired.count }.from(2).to(0)
    end

    it 'does not delete active cooldowns' do
      described_class.cleanup_expired!

      expect(described_class.in_progress).to contain_exactly(active_cooldown1, active_cooldown2)
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

    it 'returns 0 when expiry is now' do
      freeze_time do
        cooldown = build(:rate_limit_cooldown, expires_at: Time.current)
        expect(cooldown.seconds_remaining).to eq(0)
      end
    end

    it 'rounds up to nearest second' do
      freeze_time do
        cooldown = build(:rate_limit_cooldown, expires_at: 5.5.seconds.from_now)
        expect(cooldown.seconds_remaining).to eq(6)
      end
    end
  end
end
