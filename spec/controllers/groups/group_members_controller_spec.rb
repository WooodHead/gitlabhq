require 'spec_helper'

describe Groups::GroupMembersController do
  let(:user)  { create(:user) }
  let(:group) { create(:group, :public, :access_requestable) }

  describe 'GET index' do
    it 'renders index with 200 status code' do
      get :index, group_id: group

      expect(response).to have_http_status(200)
      expect(response).to render_template(:index)
    end
  end

  describe 'POST create' do
    let(:group_user) { create(:user) }

    before { sign_in(user) }

    context 'when user does not have enough rights' do
      before { group.add_developer(user) }

      it 'returns 403' do
        post :create, group_id: group,
                      user_ids: group_user.id,
                      access_level: Gitlab::Access::GUEST

        expect(response).to have_http_status(403)
        expect(group.users).not_to include group_user
      end
    end

    context 'when user has enough rights' do
      before { group.add_owner(user) }

      it 'adds user to members' do
        post :create, group_id: group,
                      user_ids: group_user.id,
                      access_level: Gitlab::Access::GUEST

        expect(response).to set_flash.to 'Users were successfully added.'
        expect(response).to redirect_to(group_group_members_path(group))
        expect(group.users).to include group_user
      end

      it 'adds no user to members' do
        post :create, group_id: group,
                      user_ids: '',
                      access_level: Gitlab::Access::GUEST

        expect(response).to set_flash.to 'No users specified.'
        expect(response).to redirect_to(group_group_members_path(group))
        expect(group.users).not_to include group_user
      end
    end
  end

  describe 'DELETE destroy' do
    let(:member) { create(:group_member, :developer, group: group) }

    before { sign_in(user) }

    context 'when member is not found' do
      it 'returns 403' do
        delete :destroy, group_id: group, id: 42

        expect(response).to have_http_status(403)
      end
    end

    context 'when member is found' do
      context 'when user does not have enough rights' do
        before { group.add_developer(user) }

        it 'returns 403' do
          delete :destroy, group_id: group, id: member

          expect(response).to have_http_status(403)
          expect(group.members).to include member
        end
      end

      context 'when user has enough rights' do
        before { group.add_owner(user) }

        it '[HTML] removes user from members' do
          delete :destroy, group_id: group, id: member

          expect(response).to set_flash.to 'User was successfully removed from group.'
          expect(response).to redirect_to(group_group_members_path(group))
          expect(group.members).not_to include member
        end

        it '[JS] removes user from members' do
          xhr :delete, :destroy, group_id: group, id: member

          expect(response).to be_success
          expect(group.members).not_to include member
        end
      end
    end
  end

  describe 'DELETE leave' do
    before { sign_in(user) }

    context 'when member is not found' do
      it 'returns 404' do
        delete :leave, group_id: group

        expect(response).to have_http_status(404)
      end
    end

    context 'when member is found' do
      context 'and is not an owner' do
        before { group.add_developer(user) }

        it 'removes user from members' do
          delete :leave, group_id: group

          expect(response).to set_flash.to "You left the \"#{group.name}\" group."
          expect(response).to redirect_to(dashboard_groups_path)
          expect(group.users).not_to include user
        end
      end

      context 'and is an owner' do
        before { group.add_owner(user) }

        it 'cannot removes himself from the group' do
          delete :leave, group_id: group

          expect(response).to have_http_status(403)
        end
      end

      context 'and is a requester' do
        before { group.request_access(user) }

        it 'removes user from members' do
          delete :leave, group_id: group

          expect(response).to set_flash.to 'Your access request to the group has been withdrawn.'
          expect(response).to redirect_to(group_path(group))
          expect(group.requesters).to be_empty
          expect(group.users).not_to include user
        end
      end
    end
  end

  describe 'POST request_access' do
    before { sign_in(user) }

    it 'creates a new GroupMember that is not a team member' do
      post :request_access, group_id: group

      expect(response).to set_flash.to 'Your request for access has been queued for review.'
      expect(response).to redirect_to(group_path(group))
      expect(group.requesters.exists?(user_id: user)).to be_truthy
      expect(group.users).not_to include user
    end
  end

  describe 'POST approve_access_request' do
    let(:member) { create(:group_member, :access_request, group: group) }

    before { sign_in(user) }

    context 'when member is not found' do
      it 'returns 403' do
        post :approve_access_request, group_id: group, id: 42

        expect(response).to have_http_status(403)
      end
    end

    context 'when member is found' do
      context 'when user does not have enough rights' do
        before { group.add_developer(user) }

        it 'returns 403' do
          post :approve_access_request, group_id: group, id: member

          expect(response).to have_http_status(403)
          expect(group.members).not_to include member
        end
      end

      context 'when user has enough rights' do
        before { group.add_owner(user) }

        it 'adds user to members' do
          post :approve_access_request, group_id: group, id: member

          expect(response).to redirect_to(group_group_members_path(group))
          expect(group.members).to include member
        end
      end
    end
  end
end
