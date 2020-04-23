with Compiler.EnumDescriptorProto;
with Compiler.FieldDescriptorProto;
with Compiler.Tools;

with Google_Protobuf.EnumDescriptorProto;

package body Compiler.DescriptorProto is

   use type Ada_Pretty.Node_Access;

   function "+" (Text : Wide_Wide_String)
     return League.Strings.Universal_String
       renames League.Strings.To_Universal_String;

   F : Ada_Pretty.Factory renames Compiler.Contexts.F;

   function Dependency
     (Self : Google_Protobuf.DescriptorProto.Instance)
      return Compiler.Contexts.String_Sets.Set
   is
      Result : Compiler.Contexts.String_Sets.Set;
   begin
      Result.Insert (+"Ada.Finalization");
      Result.Insert (+"Ada.Streams");

      for J in 0 .. Self.Field_Size - 1 loop
         Result.Union
           (Compiler.FieldDescriptorProto.Dependency (Self.Get_Field (J).all));
      end loop;

      for J in 0 .. Self.Nested_Type_Size - 1 loop
         Result.Union (Dependency (Self.Get_Nested_Type (J).all));
      end loop;

      return Result;
   end Dependency;

   ----------------
   -- Enum_Types --
   ----------------

   function Enum_Types
     (Self : Google_Protobuf.DescriptorProto.Instance)
     return Ada_Pretty.Node_Access
   is
      Result : Ada_Pretty.Node_Access;
      Item   : Ada_Pretty.Node_Access;
      Enum   : Google_Protobuf.EnumDescriptorProto
        .EnumDescriptorProto_Access;
   begin
      for J in 0 .. Self.Enum_Type_Size - 1 loop
         Enum := Self.Get_Enum_Type (J);
         Item := Compiler.EnumDescriptorProto.Public_Spec (Enum.all);

         Result := F.New_List (Result, Item);
      end loop;

      for J in 0 .. Self.Nested_Type_Size - 1 loop
         Item := Enum_Types (Self.Get_Nested_Type (J).all);

         if Item /= null then
            Result := F.New_List (Result, Item);
         end if;
      end loop;

      return Result;
   end Enum_Types;

   -----------------------
   -- Populate_Type_Map --
   -----------------------

   procedure Populate_Type_Map
     (Self        : Google_Protobuf.DescriptorProto.DescriptorProto_Access;
      PB_Package  : League.Strings.Universal_String;
      Ada_Package : League.Strings.Universal_String)
   is
      use type League.Strings.Universal_String;

      Key  : League.Strings.Universal_String := PB_Package;
      Name : constant League.Strings.Universal_String := Type_Name (Self.all);
   begin
      Key.Append (".");

      if Self.Has_Name then
         Key.Append (League.Strings.From_UTF_8_String (Self.Get_Name));
      end if;

      Compiler.Contexts.Type_Map.Insert
        (Key, (Package_Name => Ada_Package,
               Type_Name    => Name,
               Default      => League.Strings.Empty_Universal_String,
               Message      => Self));

      for J in 0 .. Self.Nested_Type_Size - 1 loop
         Populate_Type_Map
           (Self.Get_Nested_Type (J),
            PB_Package => Key,
            Ada_Package => Ada_Package);
      end loop;

      for J in 0 .. Self.Enum_Type_Size - 1 loop
         Compiler.Contexts.Type_Map.Insert
           (Key & "." &
              Compiler.EnumDescriptorProto.Proto_Type_Name
                (Self.Get_Enum_Type (J).all),
            (Package_Name => Ada_Package,
             Type_Name    => Compiler.EnumDescriptorProto.Type_Name
               (Self.Get_Enum_Type (J).all),
             Default      => Compiler.EnumDescriptorProto.Default
               (Self.Get_Enum_Type (J).all),
             Message      => null));
      end loop;
   end Populate_Type_Map;

   -----------------
   -- Public_Spec --
   -----------------

   function Public_Spec
     (Self : Google_Protobuf.DescriptorProto.Instance)
      return Ada_Pretty.Node_Access
   is
      use type League.Strings.Universal_String;
      My_Name : constant League.Strings.Universal_String := Type_Name (Self);
      Me     : constant Ada_Pretty.Node_Access := F.New_Name (My_Name);
      V_Name : Ada_Pretty.Node_Access;
      P_Self : Ada_Pretty.Node_Access;
      Is_Set : Ada_Pretty.Node_Access;
      Vector : Ada_Pretty.Node_Access;
      Getter : Ada_Pretty.Node_Access;
      Count  : Ada_Pretty.Node_Access;
      Clear  : Ada_Pretty.Node_Access;
      Append : Ada_Pretty.Node_Access;
      Option : Ada_Pretty.Node_Access;
      Result : Ada_Pretty.Node_Access;
      Item   : Ada_Pretty.Node_Access;
   begin
      for J in 0 .. Self.Field_Size - 1 loop
         Item := Compiler.FieldDescriptorProto.Component
           (Self.Get_Field (J).all);

         Result := F.New_List (Result, Item);
      end loop;

      Result := F.New_Type
        (F.New_Name (My_Name),
         Definition => F.New_Record (Components => Result));

      Is_Set := F.New_Name (+"Is_Set");

      Option := F.New_Type
        (Name          => F.New_Name ("Optional_" & My_Name),
         Discriminants => F.New_Parameter
           (Name            => Is_Set,
            Type_Definition => F.New_Name (+"Boolean"),
            Initialization  => F.New_Name (+"False")),
         Definition    => F.New_Record
           (Components => F.New_Case
              (Expression => Is_Set,
               List       => F.New_List
                 (F.New_Case_Path
                      (Choice => F.New_Name (+"True"),
                       List   => F.New_Variable
                         (Name            => F.New_Name (+"Value"),
                          Type_Definition => Me)),
                  F.New_Case_Path
                    (Choice => F.New_Name (+"False"),
                     List   => F.New_Statement)))));

      V_Name := F.New_Name (My_Name & "_Vector");

      Vector := F.New_Type
        (Name        => V_Name,
         Definition  => F.New_Private_Record
           (Is_Tagged   => True));

      P_Self := F.New_Name (+"Self");

      Count := F.New_Subprogram_Declaration
        (F.New_Subprogram_Specification
           (Name       => F.New_Name (+"Length"),
            Parameters => F.New_Parameter
              (Name            => P_Self,
               Type_Definition => V_Name),
            Result     => F.New_Name (+"Natural")));

      Getter := F.New_Subprogram_Declaration
        (F.New_Subprogram_Specification
           (Name       => F.New_Name (+"Get"),
            Parameters => F.New_List
              (F.New_Parameter
                 (Name            => P_Self,
                  Type_Definition => V_Name),
               F.New_Parameter
                 (Name            => F.New_Name (+"Index"),
                  Type_Definition => F.New_Name (+"Positive"))),
            Result     => Me));

      Clear := F.New_Subprogram_Declaration
        (F.New_Subprogram_Specification
           (Name       => F.New_Name (+"Clear"),
            Parameters => F.New_Parameter
              (Name            => P_Self,
               Type_Definition => V_Name,
               Is_In           => True,
               Is_Out          => True)));

      Append := F.New_Subprogram_Declaration
        (F.New_Subprogram_Specification
           (Name       => F.New_Name (+"Append"),
            Parameters => F.New_List
              (F.New_Parameter
                 (Name            => P_Self,
                  Type_Definition => V_Name,
                  Is_In           => True,
                  Is_Out          => True),
               F.New_Parameter
                 (F.New_Name (+"Value"), Me))));

      Result := F.New_List
        ((Vector, Result, Option, Count, Getter, Clear, Append));

      return Result;
   end Public_Spec;

   ------------------
   -- Private_Spec --
   ------------------

   function Private_Spec
     (Self : Google_Protobuf.DescriptorProto.Instance)
      return Ada_Pretty.Node_Access
   is
      use type League.Strings.Universal_String;
      My_Name : constant League.Strings.Universal_String := Type_Name (Self);
      T_Array : Ada_Pretty.Node_Access;
      Array_Access : Ada_Pretty.Node_Access;
      Result : Ada_Pretty.Node_Access;
      Item   : Ada_Pretty.Node_Access;
      Read   : Ada_Pretty.Node_Access;
      Write  : Ada_Pretty.Node_Access;
      Use_R  : Ada_Pretty.Node_Access;
      Use_W  : Ada_Pretty.Node_Access;
      Adjust : Ada_Pretty.Node_Access;
      Final  : Ada_Pretty.Node_Access;
   begin
      for J in 0 .. Self.Nested_Type_Size - 1 loop
         Item := Private_Spec (Self.Get_Nested_Type (J).all);
         Result := F.New_List (Result, Item);
      end loop;

      Read := F.New_Subprogram_Declaration
        (F.New_Subprogram_Specification
           (Name          => F.New_Name ("Read_" & My_Name),
            Parameters    => F.New_List
              (F.New_Parameter
                   (Name            => F.New_Name (+"Stream"),
                    Type_Definition => F.New_Selected_Name
                      (+"access Ada.Streams.Root_Stream_Type'Class")),
               F.New_Parameter
                   (Name            => F.New_Name (+"Value"),
                    Type_Definition => F.New_Name (My_Name),
                    Is_Out          => True))));

      Write := F.New_Subprogram_Declaration
        (F.New_Subprogram_Specification
           (Name          => F.New_Name ("Write_" & My_Name),
            Parameters    => F.New_List
              (F.New_Parameter
                   (Name            => F.New_Name (+"Stream"),
                    Type_Definition => F.New_Selected_Name
                      (+"access Ada.Streams.Root_Stream_Type'Class")),
               F.New_Parameter
                   (Name            => F.New_Name (+"Value"),
                    Type_Definition => F.New_Name (My_Name)))));

      Use_R := F.New_Statement
        (F.New_Name ("for " & My_Name & "'Read use Read_" & My_Name));

      Use_W := F.New_Statement
        (F.New_Name ("for " & My_Name & "'Write use Write_" & My_Name));

      T_Array := F.New_Type
        (Name          => F.New_Name (My_Name & "_Array"),
         Definition    => F.New_Array
           (Indexes   => F.New_Name (+"Positive range <>"),
            Component => F.New_Name (My_Name)));

      Array_Access := F.New_Type
        (Name          => F.New_Name (My_Name & "_Array_Access"),
         Definition    => F.New_Access
           (Target   => F.New_Name (My_Name & "_Array")));

      Item := F.New_Type
        (F.New_Name (Type_Name (Self) & "_Vector"),
         Definition => F.New_Record
           (Parent      => F.New_Selected_Name
                (+"Ada.Finalization.Controlled"),
            Components  => F.New_List
              (F.New_Variable
                  (Name            => F.New_Name (+"Data"),
                   Type_Definition => F.New_Name (My_Name & "_Array_Access")),
               F.New_Variable
                  (Name            => F.New_Name (+"Length"),
                   Type_Definition => F.New_Name (+"Natural")))));

      Adjust := F.New_Subprogram_Declaration
        (F.New_Subprogram_Specification
           (Is_Overriding => Ada_Pretty.True,
            Name          => F.New_Name (+"Adjust"),
            Parameters    => F.New_Parameter
              (Name            => F.New_Name (+"Self"),
               Type_Definition => F.New_Name (Type_Name (Self) & "_Vector"),
               Is_In           => True,
               Is_Out          => True)));

      Final := F.New_Subprogram_Declaration
        (F.New_Subprogram_Specification
           (Is_Overriding => Ada_Pretty.True,
            Name          => F.New_Name (+"Finalize"),
            Parameters    => F.New_Parameter
              (Name            => F.New_Name (+"Self"),
               Type_Definition => F.New_Name (Type_Name (Self) & "_Vector"),
               Is_In           => True,
               Is_Out          => True)));

      Result := F.New_List
        (Result,
         F.New_List
           ((Read, Write, Use_R, Use_W,
            T_Array, Array_Access, Item, Adjust, Final)));

      return Result;
   end Private_Spec;

   ---------------
   -- Type_Name --
   ---------------

   function Type_Name
     (Self : Google_Protobuf.DescriptorProto.Instance)
      return League.Strings.Universal_String
   is
      Result : League.Strings.Universal_String;
   begin
      if Self.Has_Name then
         declare
            Value : constant League.Strings.Universal_String :=
              League.Strings.From_UTF_8_String (Self.Get_Name);
         begin
            Result := Compiler.Tools.To_Ada_Name (Value);
         end;
      else
         Result.Append ("Message");
      end if;

      return Result;
   end Type_Name;

end Compiler.DescriptorProto;
