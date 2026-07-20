# frozen_string_literal: true

# Copyright (c) 2026. BienenSchweiz. This file is part of
# hitobito_bienenschweiz and licensed under the Affero General Public License version 3
# or later. See the COPYING file at the top-level directory or at
# https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz

class MemosController < CrudController
  self.nesting = Group, Person

  self.permitted_attrs = [:title, :body]

  decorates :group, :person

  prepend_before_action :parent

  def create
    entry.author = current_user
    super(location: index_path)
  end

  def update
    super(location: index_path)
  end

  def destroy
    super(location: index_path)
  end

  private

  def build_entry
    @person.memos.build
  end
end
