# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Spotify Authentication', type: :system do
  before do
    driven_by(:rack_test)

    OmniAuth.config.add_mock(:spotify, {
                               uid: 'spotify123',
                               info: {
                                 email: 'test@example.com',
                                 display_name: 'Test User'
                               },
                               credentials: {
                                 token: 'mock_access_token',
                                 refresh_token: 'mock_refresh_token',
                                 expires_at: 1.hour.from_now.to_i
                               }
                             })
  end

  context 'when signing in for the first time' do
    it 'creates a new user and shows success page' do
      visit root_path

      expect(page).to have_content('Welcome to Genre Orb')
      expect(page).to have_button('Sign in with Spotify')

      expect do
        click_button 'Sign in with Spotify'
      end.to change(User, :count).from(0).to(1)

      expect(page).to have_content('Successfully Signed In!')

      expect(User.last).to have_attributes(
        spotify_id: 'spotify123',
        spotify_email: 'test@example.com',
        spotify_display_name: 'Test User'
      )
    end
  end

  context 'when re-authenticating with existing account' do
    let!(:existing_user) do
      create(:user,
             spotify_id: 'spotify123',
             access_token: 'old_token',
             refresh_token: 'old_refresh_token')
    end

    it 'updates existing user tokens without creating new user' do
      visit root_path

      expect do
        click_button 'Sign in with Spotify'
      end.not_to change(User, :count)

      expect(page).to have_content('Successfully Signed In!')

      expect(existing_user.reload).to have_attributes(
        access_token: 'mock_access_token',
        refresh_token: 'mock_refresh_token'
      )
    end
  end
end
