# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Spotify Authentication', type: :request do
  describe 'GET /auth/spotify/callback' do
    before do
      OmniAuth.config.add_mock(:spotify, {
                                 uid: 'spotify123',
                                 info: {
                                   email: 'test@example.com',
                                   display_name: 'Test User'
                                 },
                                 credentials: {
                                   token: 'access_token_123',
                                   refresh_token: 'refresh_token_123',
                                   expires_at: 1.hour.from_now.to_i
                                 }
                               })
    end

    context 'with successful authorization' do
      it 'redirects to success page' do
        get '/auth/spotify/callback'
        expect(response).to redirect_to(auth_success_path)
      end

      it 'creates a user via the service' do
        expect { get '/auth/spotify/callback' }.to change(User, :count).by(1)
      end
    end

    context 'with invalid auth payload' do
      before do
        OmniAuth.config.add_mock(:spotify, {
                                   uid: 'spotify123',
                                   info: { email: 'test@example.com' }
                                   # Missing credentials hash
                                 })
      end

      it 'redirects to failure path' do
        get '/auth/spotify/callback'
        expect(response).to redirect_to(root_path)
      end

      it 'sets error flash message' do
        get '/auth/spotify/callback'
        expect(flash[:alert]).to eq('An unexpected error occurred during authentication')
      end

      it 'does not create a user' do
        expect { get '/auth/spotify/callback' }.not_to change(User, :count)
      end
    end

    context 'when unexpected error occurs' do
      before do
        allow(AuthorizeSpotifyUserService).to receive(:call)
          .and_raise(StandardError, 'Unexpected error')
      end

      it 'redirects to failure path' do
        get '/auth/spotify/callback'
        expect(response).to redirect_to(root_path)
      end

      it 'sets error flash message' do
        get '/auth/spotify/callback'
        expect(flash[:alert]).to include('unexpected error')
      end
    end
  end

  describe 'GET /auth/success' do
    it 'renders success page' do
      get '/auth/success'
      expect(response).to have_http_status(:success)
      expect(response.body).to include('Successfully Signed In!')
    end
  end
end
