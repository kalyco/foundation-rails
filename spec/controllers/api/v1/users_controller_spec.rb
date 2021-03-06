require 'rails_helper'

describe Api::V1::UsersController do

  describe '#index' do
    before do
      create(:user)
    end

    it 'should not return a list of users for a guest' do
      get :index, format: :json
      expect(response.status).to eq 401
    end

    it 'should not allow a normal user' do
      @user = create(:user)
      authenticate_as @user
      get :index, format: :json
      expect(response).to render_unauthorized
    end


    it 'should return a list of users for an admin' do
      @admin = create(:admin)
      authenticate_as @admin
      get :index, format: :json
      expect(json_response['data'].length).to eq User.count
    end
  end

  describe '#create' do
    before do
      @attrss = attributes_for(:user)
    end

    it 'should respond with errors for an invalid user' do
      @attrss.delete(:email)
      post :create, user: @attrss, format: :json
      expect(response.status).to eq 422
    end

    it 'should allow creation of a valid user' do
      post :create, user: @attrss, format: :json
      expect(response.status).to eq 200
    end
  end

  describe '#update' do
    before do
      @admin = create(:admin)
      @attrs = attributes_for(:user)
      @user =User.create(@attrs)
      @attrs.delete :password
      @attrs.delete :password_confirmation
    end

    it 'renders unauthorized for an unauthorized user' do
      user = create(:user)
      authenticate_as user
      put :update, id: @user.id, user: @attrs, format: :json
      expect(response).to render_unauthorized
    end

    it 'renders unauthorized for updating a record with insufficient permissions' do
      other = create(:user)
      authenticate_as other
      put :update, id: @user.id, user: @attrs, format: :json
      expect(response).to render_unauthorized
    end

    it 'updates a record' do
      authenticate_as @user
      email = 'user@gmail.com'
      @attrs[:email] = email
      put :update, id: @user.id, user: @attrs, format: :json
      expect(json_response['data']['type']).to include('users')
      expect(json_response['data']['attributes']['email']).to eq email
    end

    it "doesn't allow a user to update their admin" do
      authenticate_as @user
      @attrs[:admin] = true
      put :update, id: @user.id, user: @attrs, format: :json
      expect(json_response['data']['attributes']['admin']).to eq false
    end

    it 'renders an update for a authorized user' do
      authenticate_as @admin
      @attrs[:admin] = true
      put :update, id: @user.id, user: @attrs, format: :json
      expect(response.status).to eq 200
    end
  end

  describe '#destroy' do
    before do
      @admin = create(:admin)
      @user = create(:user)
    end

    it 'should not allow unauthorized users' do
      other_user = create(:user)
      authenticate_as other_user
      delete :destroy, id: @user.id, format: :json
      expect(response).to render_unauthorized
    end

    it 'should allow a user to delete their own record' do
      authenticate_as @user
      expect {
        delete :destroy, id: @user.id, format: :json
      }.to change(User, :count).by(-1)
    end

    it 'should allow an admin to delete the record' do
      authenticate_as @admin
      expect {
        delete :destroy, id: @user.id, format: :json
      }.to change(User, :count).by(-1)
    end
  end
end
