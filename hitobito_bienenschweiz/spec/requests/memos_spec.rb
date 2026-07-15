# frozen_string_literal: true

#  Copyright (c) 2026, BienenSchweiz. This file is part of
#  hitobito_bienenschweiz and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz.

require "spec_helper"

RSpec.describe MemosController, type: :request do
  let(:sektion) { groups(:aarau_und_umgebung) }
  let(:admin) { people(:admin) }
  let(:person) { Fabricate(:person) }

  before do
    roles(:admin)
    sign_in(admin)
  end

  describe "#index" do
    let!(:memos) do
      [
        Fabricate(:memo, person: person, author: admin, title: "First Memo", body: "Content A"),
        Fabricate(:memo, person: person, author: admin, title: "Second Memo", body: "Content B")
      ]
    end

    it "shows memo titles as links and does not show body text" do
      get group_person_memos_path(sektion, person)
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("First Memo")
      expect(response.body).to include("Second Memo")
      expect(response.body).to include(admin.full_name)
      expect(response.body).not_to include("Content A")
      expect(response.body).not_to include("Content B")
    end
  end

  describe "#show" do
    let!(:memo) do
      Fabricate(:memo, person: person, author: admin,
        title: "Important Note", body: "Line one\nLine two")
    end

    it "shows all memo attributes" do
      get group_person_memo_path(sektion, person, memo)
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Important Note")
      expect(response.body).to include(admin.full_name)
      expect(response.body).to include("Line one")
      expect(response.body).to include("Line two")
    end

    it "renders newlines as HTML line breaks" do
      get group_person_memo_path(sektion, person, memo)
      expect(response.body).to include("<br />")
    end
  end

  describe "#new" do
    it "renders the new memo form" do
      get new_group_person_memo_path(sektion, person)
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Titel")
      expect(response.body).to include("Text")
    end
  end

  describe "#create" do
    let(:memo_params) { {title: "New Memo", body: "Memo body text"} }

    it "creates a new memo" do
      expect do
        post group_person_memos_path(sektion, person), params: {memo: memo_params}
      end.to change { Memo.count }.by(1)

      memo = Memo.last
      expect(memo.person).to eq(person)
      expect(memo.author).to eq(admin)
      expect(memo.author_name).to eq(admin.full_name)
      expect(memo.title).to eq("New Memo")
      expect(memo.body).to eq("Memo body text")
    end

    it "redirects to the memos index after creation" do
      post group_person_memos_path(sektion, person), params: {memo: memo_params}
      expect(response.location).to include(group_person_memos_path(sektion, person))
    end

    context "with invalid params" do
      it "does not create a memo and renders the form with errors" do
        expect do
          post group_person_memos_path(sektion, person), params: {memo: {title: "", body: ""}}
        end.not_to change { Memo.count }

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.body).to include("muss ausgefüllt werden")
      end
    end
  end

  describe "#edit" do
    let!(:memo) { Fabricate(:memo, person: person, author: admin) }

    it "renders the edit form" do
      get edit_group_person_memo_path(sektion, person, memo)
      expect(response).to have_http_status(:ok)
      expect(response.body).to include(memo.title)
    end
  end

  describe "#update" do
    let!(:memo) { Fabricate(:memo, person: person, author: admin, title: "Old Title") }

    it "updates the memo" do
      patch group_person_memo_path(sektion, person, memo),
        params: {memo: {title: "New Title", body: "Updated body"}}

      expect(memo.reload.title).to eq("New Title")
    end

    it "redirects to the memos index after update" do
      patch group_person_memo_path(sektion, person, memo),
        params: {memo: {title: "New Title", body: "Updated body"}}
      expect(response.location).to include(group_person_memos_path(sektion, person))
    end
  end

  describe "#destroy" do
    let!(:memo) { Fabricate(:memo, person: person, author: admin) }

    it "destroys the memo" do
      expect do
        delete group_person_memo_path(sektion, person, memo)
      end.to change { Memo.count }.by(-1)
    end

    it "redirects to the memos index after deletion" do
      delete group_person_memo_path(sektion, person, memo)
      expect(response.location).to include(group_person_memos_path(sektion, person))
    end
  end

  describe "authorization" do
    context "as a non-admin person" do
      before { sign_in(Fabricate(:person)) }

      it "denies index access" do
        expect do
          get group_person_memos_path(sektion, person)
        end.to raise_error(CanCan::AccessDenied)
      end

      it "denies create access" do
        expect do
          post group_person_memos_path(sektion, person),
            params: {memo: {title: "x", body: "y"}}
        end.to raise_error(CanCan::AccessDenied)
      end
    end
  end
end
