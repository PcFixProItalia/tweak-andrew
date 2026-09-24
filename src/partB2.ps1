
# ------------------------------------------------------------------------------
# 1. INTERFACCIA XAML - stile PcFixPro: blu #1E90FF, vetro satinato, tema scuro
# ------------------------------------------------------------------------------
# Here-string LETTERALE: il markup non deve mai passare per l'interpolazione di
# PowerShell, altrimenti un eventuale "$" nel testo verrebbe risolto come variabile.
# I commenti XML non possono contenere due trattini di seguito.
[xml]$xaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        xmlns:shell="clr-namespace:System.Windows.Shell;assembly=PresentationFramework"
        xmlns:sys="clr-namespace:System;assembly=mscorlib"
        Title="Tweak Andrew v6.0 - PcFixPro Italia" Height="840" Width="1340"
        MinWidth="1180" MinHeight="700"
        WindowStartupLocation="CenterScreen"
        WindowStyle="None" AllowsTransparency="False" Background="#FF000000"
        Foreground="#F2F2F5" TextOptions.TextFormattingMode="Ideal" UseLayoutRounding="True"
        ResizeMode="CanResize">

    <shell:WindowChrome.WindowChrome>
        <shell:WindowChrome CaptionHeight="52" ResizeBorderThickness="6"
                            GlassFrameThickness="-1" CornerRadius="0" UseAeroCaptionButtons="False"/>
    </shell:WindowChrome.WindowChrome>

    <Window.Resources>
        <!-- Testi dei modelli: il codice li sostituisce quando cambia la lingua. -->
        <sys:String x:Key="BadgeActive">Attivo</sys:String>

        <!-- Tema nero AMOLED: il nero pieno e' lo sfondo, le superfici salgono di
             pochi punti di luminosita'. Ogni pagina ridefinisce PA, PASoft e
             PACard con il proprio colore: il resto dello stile li legge da li'. -->
        <SolidColorBrush x:Key="PA" Color="#FF1E90FF"/>
        <SolidColorBrush x:Key="PASoft" Color="#261E90FF"/>
        <LinearGradientBrush x:Key="PACard" StartPoint="0,0" EndPoint="0.7,1">
            <GradientStop Color="#141E90FF" Offset="0"/>
            <GradientStop Color="#0CFFFFFF" Offset="0.55"/>
        </LinearGradientBrush>

        <SolidColorBrush x:Key="Accent" Color="#FF1E90FF"/>
        <SolidColorBrush x:Key="AccentDeep" Color="#FF0A6ED1"/>
        <SolidColorBrush x:Key="SoftBlue" Color="#FF7FC4E8"/>
        <SolidColorBrush x:Key="TextMain" Color="#FFF2F2F5"/>
        <SolidColorBrush x:Key="TextDim" Color="#FFA1A1AA"/>
        <SolidColorBrush x:Key="Success" Color="#FF2ED3A7"/>
        <SolidColorBrush x:Key="Warn" Color="#FFE0A25E"/>
        <SolidColorBrush x:Key="Outline" Color="#FF1C1C21"/>
        <SolidColorBrush x:Key="OutlineStrong" Color="#FF2A2A31"/>
        <SolidColorBrush x:Key="Surface" Color="#FF0B0B0D"/>
        <SolidColorBrush x:Key="Surface2" Color="#FF131316"/>

        <SolidColorBrush x:Key="AccentGradient" Color="#FF1E90FF"/>
        <SolidColorBrush x:Key="AccentGradientHover" Color="#FF4AA8FF"/>

        <Style x:Key="ScrollThumb" TargetType="Thumb">
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Thumb">
                        <Border x:Name="t" CornerRadius="3" Background="#FF26262C" Margin="3,0"/>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter TargetName="t" Property="Background" Value="{DynamicResource PA}"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>
        <Style TargetType="ScrollBar">
            <Setter Property="Width" Value="9"/>
            <Setter Property="Background" Value="Transparent"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="ScrollBar">
                        <Grid Background="Transparent">
                            <Track x:Name="PART_Track" IsDirectionReversed="True">
                                <Track.DecreaseRepeatButton>
                                    <RepeatButton Command="ScrollBar.PageUpCommand" Opacity="0" Focusable="False"/>
                                </Track.DecreaseRepeatButton>
                                <Track.Thumb>
                                    <Thumb Style="{StaticResource ScrollThumb}"/>
                                </Track.Thumb>
                                <Track.IncreaseRepeatButton>
                                    <RepeatButton Command="ScrollBar.PageDownCommand" Opacity="0" Focusable="False"/>
                                </Track.IncreaseRepeatButton>
                            </Track>
                        </Grid>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <!-- Casella come interruttore Material: testo a sinistra, levetta a destra. -->
        <Style TargetType="CheckBox">
            <Setter Property="ToolTipService.InitialShowDelay" Value="450"/>
            <Setter Property="ToolTipService.BetweenShowDelay" Value="150"/>
            <Setter Property="ToolTipService.ShowDuration" Value="30000"/>
            <Setter Property="Foreground" Value="#FFC4C4CC"/>
            <Setter Property="FontFamily" Value="Roboto, Segoe UI Variable Text, Segoe UI"/>
            <Setter Property="FontSize" Value="12.5"/>
            <Setter Property="Margin" Value="0,1"/>
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="HorizontalAlignment" Value="Stretch"/>
            <Setter Property="HorizontalContentAlignment" Value="Left"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="CheckBox">
                        <Border x:Name="row" Background="Transparent" CornerRadius="12" Padding="10,8" SnapsToDevicePixels="True">
                            <Grid>
                                <Grid.ColumnDefinitions>
                                    <ColumnDefinition Width="*"/>
                                    <ColumnDefinition Width="Auto"/>
                                    <ColumnDefinition Width="Auto"/>
                                    <ColumnDefinition Width="Auto"/>
                                </Grid.ColumnDefinitions>
                                <ContentPresenter Grid.Column="0" VerticalAlignment="Center" Margin="0,0,14,0">
                                    <ContentPresenter.ContentTemplate>
                                        <DataTemplate>
                                            <TextBlock Text="{Binding}" TextWrapping="Wrap"/>
                                        </DataTemplate>
                                    </ContentPresenter.ContentTemplate>
                                </ContentPresenter>
                                <!-- Gia' attivo sul sistema: lo segna il rilevamento all'avvio. -->
                                <Border x:Name="badge" Grid.Column="1" Visibility="Collapsed" CornerRadius="6" Padding="7,2"
                                        Background="#262ED3A7" VerticalAlignment="Center" Margin="0,0,10,0">
                                    <TextBlock Text="{DynamicResource BadgeActive}" FontSize="10.5" FontWeight="SemiBold" Foreground="#FF2ED3A7"/>
                                </Border>
                                <!-- Voce consigliata: la stellina la seleziona; si applica con «Applica modifiche». -->
                                <Border x:Name="starHit" Grid.Column="2" Visibility="Collapsed" Background="Transparent"
                                        Width="24" Height="24" Margin="0,0,8,0" VerticalAlignment="Center">
                                    <Path x:Name="star" Width="14" Height="14" Stretch="Uniform" StrokeThickness="1.4" StrokeLineJoin="Round"
                                          Stroke="#FF6E6E78" Fill="Transparent" HorizontalAlignment="Center" VerticalAlignment="Center"
                                          Data="M12,2 L14.9,8.3 L21.8,9 L16.6,13.6 L18.1,20.4 L12,16.9 L5.9,20.4 L7.4,13.6 L2.2,9 L9.1,8.3 Z"/>
                                </Border>
                                <Border x:Name="track" Grid.Column="3" Width="36" Height="20" CornerRadius="10"
                                        Background="#FF121215" BorderBrush="#FF3A3A42" BorderThickness="1.5"
                                        VerticalAlignment="Center">
                                    <Border x:Name="thumb" Width="10" Height="10" CornerRadius="5" Background="#FF7A7A84"
                                            HorizontalAlignment="Left" VerticalAlignment="Center" Margin="4.5,0,0,0">
                                        <Border.RenderTransform>
                                            <TranslateTransform X="0"/>
                                        </Border.RenderTransform>
                                    </Border>
                                </Border>
                            </Grid>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter TargetName="row" Property="Background" Value="#FF0F0F12"/>
                                <Setter TargetName="track" Property="BorderBrush" Value="#FF55555F"/>
                            </Trigger>
                            <Trigger Property="AutomationProperties.HelpText" Value="active">
                                <Setter TargetName="badge" Property="Visibility" Value="Visible"/>
                            </Trigger>
                            <Trigger Property="AutomationProperties.ItemStatus" Value="rec">
                                <Setter TargetName="starHit" Property="Visibility" Value="Visible"/>
                            </Trigger>
                            <Trigger SourceName="starHit" Property="IsMouseOver" Value="True">
                                <Setter TargetName="star" Property="Stroke" Value="{DynamicResource PA}"/>
                            </Trigger>
                            <MultiTrigger>
                                <MultiTrigger.Conditions>
                                    <Condition Property="AutomationProperties.ItemStatus" Value="rec"/>
                                    <Condition Property="IsChecked" Value="True"/>
                                </MultiTrigger.Conditions>
                                <Setter TargetName="star" Property="Fill" Value="{DynamicResource PA}"/>
                                <Setter TargetName="star" Property="Stroke" Value="{DynamicResource PA}"/>
                            </MultiTrigger>
                            <Trigger Property="IsChecked" Value="True">
                                <Setter TargetName="track" Property="Background" Value="{DynamicResource PA}"/>
                                <Setter TargetName="track" Property="BorderBrush" Value="{DynamicResource PA}"/>
                                <Setter TargetName="thumb" Property="Background" Value="#FF000000"/>
                                <Setter TargetName="thumb" Property="Width" Value="14"/>
                                <Setter TargetName="thumb" Property="Height" Value="14"/>
                                <Setter TargetName="thumb" Property="CornerRadius" Value="7"/>
                                <Setter TargetName="thumb" Property="Margin" Value="2.5,0,0,0"/>
                                <Setter Property="Foreground" Value="#FFFFFFFF"/>
                                <Trigger.EnterActions>
                                    <BeginStoryboard>
                                        <Storyboard>
                                            <DoubleAnimation Storyboard.TargetName="thumb"
                                                             Storyboard.TargetProperty="(UIElement.RenderTransform).(TranslateTransform.X)"
                                                             To="16" Duration="0:0:0.14"/>
                                        </Storyboard>
                                    </BeginStoryboard>
                                </Trigger.EnterActions>
                                <Trigger.ExitActions>
                                    <BeginStoryboard>
                                        <Storyboard>
                                            <DoubleAnimation Storyboard.TargetName="thumb"
                                                             Storyboard.TargetProperty="(UIElement.RenderTransform).(TranslateTransform.X)"
                                                             To="0" Duration="0:0:0.14"/>
                                        </Storyboard>
                                    </BeginStoryboard>
                                </Trigger.ExitActions>
                            </Trigger>
                            <Trigger Property="IsEnabled" Value="False">
                                <Setter Property="Opacity" Value="0.35"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <!-- Riga selezionabile delle app: casella quadrata a sinistra, tutta la
             riga cliccabile, colore della pagina quando e' scelta. -->
        <!-- Profilo a scheda: tutto il riquadro si sceglie, bordo del colore della pagina. -->
        <Style x:Key="ProfileCard" TargetType="RadioButton">
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="Margin" Value="0,0,0,8"/>
            <Setter Property="FocusVisualStyle" Value="{x:Null}"/>
            <Setter Property="HorizontalContentAlignment" Value="Stretch"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="RadioButton">
                        <Border x:Name="card" Background="#FF0C0C0F" BorderBrush="#FF1F1F25" BorderThickness="1.5"
                                CornerRadius="14" Padding="14,12">
                            <ContentPresenter/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter TargetName="card" Property="Background" Value="#FF121215"/>
                            </Trigger>
                            <Trigger Property="IsChecked" Value="True">
                                <Setter TargetName="card" Property="BorderBrush" Value="{DynamicResource PA}"/>
                                <Setter TargetName="card" Property="Background" Value="{DynamicResource PASoft}"/>
                            </Trigger>
                            <Trigger Property="IsEnabled" Value="False">
                                <Setter Property="Opacity" Value="0.45"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <Style x:Key="StarBtn" TargetType="Button">
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border x:Name="b" Background="#FF111114" BorderBrush="#FF26262C" BorderThickness="1" CornerRadius="12" Width="38">
                            <Path x:Name="star" Width="15" Height="15" Stretch="Uniform" StrokeThickness="1.5" StrokeLineJoin="Round"
                                  Stroke="#FF8E8E98" Fill="Transparent" HorizontalAlignment="Center" VerticalAlignment="Center"
                                  Data="M12,2 L14.9,8.3 L21.8,9 L16.6,13.6 L18.1,20.4 L12,16.9 L5.9,20.4 L7.4,13.6 L2.2,9 L9.1,8.3 Z"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter TargetName="b" Property="BorderBrush" Value="{DynamicResource PA}"/>
                                <Setter TargetName="star" Property="Fill" Value="{DynamicResource PA}"/>
                                <Setter TargetName="star" Property="Stroke" Value="{DynamicResource PA}"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <Style x:Key="PickRow" TargetType="CheckBox">
            <Setter Property="Foreground" Value="#FFC4C4CC"/>
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="Margin" Value="0,2"/>
            <Setter Property="FocusVisualStyle" Value="{x:Null}"/>
            <Setter Property="HorizontalAlignment" Value="Stretch"/>
            <Setter Property="HorizontalContentAlignment" Value="Stretch"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="CheckBox">
                        <Border x:Name="row" Background="#FF0C0C0F" BorderBrush="#FF1A1A1F" BorderThickness="1"
                                CornerRadius="12" Padding="11,8" SnapsToDevicePixels="True">
                            <Grid>
                                <Grid.ColumnDefinitions>
                                    <ColumnDefinition Width="Auto"/>
                                    <ColumnDefinition Width="*"/>
                                </Grid.ColumnDefinitions>
                                <Border x:Name="box" Width="20" Height="20" CornerRadius="6" BorderThickness="1.6"
                                        BorderBrush="#FF4A4A53" Background="#FF101013" VerticalAlignment="Center" Margin="0,0,12,0">
                                    <Path x:Name="tick" Data="M3.6,8.6 L7,12 L13.4,4.8" Stroke="#FF000000" StrokeThickness="2.2"
                                          StrokeStartLineCap="Round" StrokeEndLineCap="Round" StrokeLineJoin="Round"
                                          Visibility="Collapsed"/>
                                </Border>
                                <ContentPresenter Grid.Column="1" VerticalAlignment="Center" HorizontalAlignment="Stretch"/>
                            </Grid>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter TargetName="row" Property="Background" Value="#FF121215"/>
                                <Setter TargetName="box" Property="BorderBrush" Value="{DynamicResource PA}"/>
                            </Trigger>
                            <Trigger Property="IsChecked" Value="True">
                                <Setter TargetName="row" Property="Background" Value="{DynamicResource PASoft}"/>
                                <Setter TargetName="row" Property="BorderBrush" Value="{DynamicResource PA}"/>
                                <Setter TargetName="box" Property="Background" Value="{DynamicResource PA}"/>
                                <Setter TargetName="box" Property="BorderBrush" Value="{DynamicResource PA}"/>
                                <Setter TargetName="tick" Property="Visibility" Value="Visible"/>
                            </Trigger>
                            <Trigger Property="IsEnabled" Value="False">
                                <Setter Property="Opacity" Value="0.45"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <!-- Casella piccola accanto al titolo di una scheda: sceglie tutte le voci
             della sezione. Stessa casella quadrata delle app, in formato ridotto. -->
        <Style x:Key="SectionPick" TargetType="CheckBox">
            <Setter Property="Foreground" Value="#FF8E8E98"/>
            <Setter Property="FontFamily" Value="Roboto, Segoe UI"/>
            <Setter Property="FontSize" Value="11.5"/>
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="FocusVisualStyle" Value="{x:Null}"/>
            <Setter Property="VerticalAlignment" Value="Center"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="CheckBox">
                        <Border x:Name="row" Background="Transparent" CornerRadius="8" Padding="6,3">
                            <StackPanel Orientation="Horizontal">
                                <TextBlock x:Name="txt" Text="{TemplateBinding Content}" VerticalAlignment="Center" Margin="0,0,8,0"/>
                                <Border x:Name="box" Width="16" Height="16" CornerRadius="5" BorderThickness="1.5"
                                        BorderBrush="#FF4A4A53" Background="#FF101013" VerticalAlignment="Center">
                                    <Path x:Name="tick" Data="M3,7 L5.8,9.8 L11,4" Stroke="#FF000000" StrokeThickness="2"
                                          StrokeStartLineCap="Round" StrokeEndLineCap="Round" StrokeLineJoin="Round"
                                          Visibility="Collapsed"/>
                                </Border>
                            </StackPanel>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter TargetName="box" Property="BorderBrush" Value="{DynamicResource PA}"/>
                                <Setter Property="Foreground" Value="#FFE4E4EA"/>
                            </Trigger>
                            <Trigger Property="IsChecked" Value="True">
                                <Setter TargetName="box" Property="Background" Value="{DynamicResource PA}"/>
                                <Setter TargetName="box" Property="BorderBrush" Value="{DynamicResource PA}"/>
                                <Setter TargetName="tick" Property="Visibility" Value="Visible"/>
                                <Setter Property="Foreground" Value="#FFFFFFFF"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <Style TargetType="RadioButton">
            <Setter Property="Foreground" Value="#FFC4C4CC"/>
            <Setter Property="FontFamily" Value="Roboto, Segoe UI Variable Text, Segoe UI"/>
            <Setter Property="FontSize" Value="12.5"/>
            <Setter Property="Margin" Value="0,2,8,2"/>
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="RadioButton">
                        <Border x:Name="row" Background="#FF0E0E11" BorderBrush="#FF232329" BorderThickness="1"
                                CornerRadius="12" Padding="12,8" SnapsToDevicePixels="True">
                            <!-- Griglia e non StackPanel orizzontale: con larghezza infinita il testo lungo non andava a capo e veniva tagliato. -->
                            <Grid>
                                <Grid.ColumnDefinitions>
                                    <ColumnDefinition Width="Auto"/>
                                    <ColumnDefinition Width="*"/>
                                </Grid.ColumnDefinitions>
                                <Grid Width="16" Height="16" Margin="0,0,10,0" VerticalAlignment="Center">
                                    <Ellipse x:Name="ring" Stroke="#FF4A4A53" StrokeThickness="1.6"/>
                                    <Ellipse x:Name="dot" Width="8" Height="8" Fill="{DynamicResource PA}" Visibility="Collapsed"/>
                                </Grid>
                                <ContentPresenter Grid.Column="1" VerticalAlignment="Center">
                                    <ContentPresenter.ContentTemplate>
                                        <DataTemplate>
                                            <TextBlock Text="{Binding}" TextWrapping="Wrap"/>
                                        </DataTemplate>
                                    </ContentPresenter.ContentTemplate>
                                </ContentPresenter>
                            </Grid>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter TargetName="row" Property="Background" Value="#FF141417"/>
                            </Trigger>
                            <Trigger Property="IsChecked" Value="True">
                                <Setter TargetName="ring" Property="Stroke" Value="{DynamicResource PA}"/>
                                <Setter TargetName="dot" Property="Visibility" Value="Visible"/>
                                <Setter TargetName="row" Property="Background" Value="{DynamicResource PASoft}"/>
                                <Setter TargetName="row" Property="BorderBrush" Value="{DynamicResource PA}"/>
                                <Setter Property="Foreground" Value="#FFFFFFFF"/>
                            </Trigger>
                            <Trigger Property="IsEnabled" Value="False">
                                <Setter Property="Opacity" Value="0.35"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <Style x:Key="NavItem" TargetType="RadioButton">
            <Setter Property="Foreground" Value="#FF8E8E98"/>
            <Setter Property="FontFamily" Value="Raleway, Segoe UI Variable Display, Segoe UI"/>
            <Setter Property="FontWeight" Value="SemiBold"/>
            <Setter Property="FontSize" Value="13"/>
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="Margin" Value="0,1"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="RadioButton">
                        <Border x:Name="bg" CornerRadius="12" Background="Transparent" Padding="13,7" SnapsToDevicePixels="True">
                            <Grid>
                                <Grid.ColumnDefinitions>
                                    <ColumnDefinition Width="Auto"/>
                                    <ColumnDefinition Width="*"/>
                                    <ColumnDefinition Width="Auto"/>
                                </Grid.ColumnDefinitions>
                                <Path x:Name="icon" Grid.Column="0" Width="17" Height="17" Stretch="Uniform"
                                      Data="{Binding Tag, RelativeSource={RelativeSource TemplatedParent}}"
                                      Stroke="#FF6E6E78" StrokeThickness="1.7" Fill="Transparent"
                                      StrokeLineJoin="Round" StrokeStartLineCap="Round" StrokeEndLineCap="Round"
                                      VerticalAlignment="Center" Margin="0,0,13,0"/>
                                <TextBlock Grid.Column="1" VerticalAlignment="Center" Text="{TemplateBinding Content}"
                                           TextTrimming="CharacterEllipsis"/>
                                <Ellipse x:Name="pip" Grid.Column="2" Width="6" Height="6" Fill="{DynamicResource PA}"
                                         VerticalAlignment="Center" Opacity="0.55"/>
                            </Grid>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter TargetName="bg" Property="Background" Value="#FF0F0F12"/>
                                <Setter Property="Foreground" Value="#FFE4E4EA"/>
                                <Setter TargetName="icon" Property="Stroke" Value="{DynamicResource PA}"/>
                            </Trigger>
                            <Trigger Property="IsChecked" Value="True">
                                <Setter TargetName="bg" Property="Background" Value="{DynamicResource PASoft}"/>
                                <Setter Property="Foreground" Value="#FFFFFFFF"/>
                                <Setter TargetName="icon" Property="Stroke" Value="{DynamicResource PA}"/>
                                <Setter TargetName="pip" Property="Opacity" Value="1"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <Style TargetType="ComboBox">
            <Setter Property="Foreground" Value="#FFF2F2F5"/>
            <Setter Property="BorderBrush" Value="#FF26262C"/>
            <Setter Property="BorderThickness" Value="1"/>
            <Setter Property="Padding" Value="12,7"/>
            <Setter Property="FontSize" Value="12"/>
            <Setter Property="FontFamily" Value="Roboto, Segoe UI"/>
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="VerticalContentAlignment" Value="Center"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="ComboBox">
                        <Grid>
                            <Grid.ColumnDefinitions>
                                <ColumnDefinition Width="*"/>
                                <ColumnDefinition Width="Auto"/>
                            </Grid.ColumnDefinitions>
                            <Border x:Name="MainBorder" Grid.ColumnSpan="2"
                                    Background="#FF111114"
                                    BorderBrush="{TemplateBinding BorderBrush}"
                                    BorderThickness="{TemplateBinding BorderThickness}"
                                    CornerRadius="12"/>
                            <ToggleButton x:Name="ToggleButton" Grid.ColumnSpan="2"
                                          Background="Transparent" BorderThickness="0" Focusable="False"
                                          IsChecked="{Binding IsDropDownOpen, RelativeSource={RelativeSource TemplatedParent}, Mode=TwoWay}"
                                          ClickMode="Press">
                                <ToggleButton.Template>
                                    <ControlTemplate TargetType="ToggleButton">
                                        <Border Background="Transparent"/>
                                    </ControlTemplate>
                                </ToggleButton.Template>
                            </ToggleButton>
                            <ContentPresenter x:Name="ContentSite" Grid.Column="0" IsHitTestVisible="False"
                                              Content="{TemplateBinding SelectionBoxItem}"
                                              ContentTemplate="{TemplateBinding SelectionBoxItemTemplate}"
                                              ContentTemplateSelector="{TemplateBinding ItemTemplateSelector}"
                                              Margin="{TemplateBinding Padding}"
                                              VerticalAlignment="Center" HorizontalAlignment="Left"
                                              TextBlock.Foreground="{TemplateBinding Foreground}"/>
                            <Path x:Name="Arrow" Grid.Column="1" Data="M1,1 L5.5,5.5 L10,1"
                                  Stroke="#FF8E8E98" StrokeThickness="1.6" Fill="Transparent"
                                  StrokeStartLineCap="Round" StrokeEndLineCap="Round" StrokeLineJoin="Round"
                                  Margin="0,0,13,0" VerticalAlignment="Center" HorizontalAlignment="Right"/>
                            <Popup x:Name="PART_Popup" AllowsTransparency="True"
                                   IsOpen="{TemplateBinding IsDropDownOpen}" Placement="Bottom"
                                   PopupAnimation="Fade" Focusable="False">
                                <Border Background="#FF0E0E11" BorderBrush="#FF26262C" BorderThickness="1"
                                        CornerRadius="14" Margin="0,6,0,0" Padding="2"
                                        MinWidth="{Binding ActualWidth, RelativeSource={RelativeSource TemplatedParent}}"
                                        MaxHeight="{TemplateBinding MaxDropDownHeight}">
                                    <ScrollViewer SnapsToDevicePixels="True" Margin="4">
                                        <ItemsPresenter/>
                                    </ScrollViewer>
                                </Border>
                            </Popup>
                        </Grid>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter TargetName="MainBorder" Property="BorderBrush" Value="{DynamicResource PA}"/>
                            </Trigger>
                            <Trigger Property="IsDropDownOpen" Value="True">
                                <Setter TargetName="MainBorder" Property="BorderBrush" Value="{DynamicResource PA}"/>
                            </Trigger>
                            <Trigger Property="IsEnabled" Value="False">
                                <Setter TargetName="MainBorder" Property="Background" Value="#FF0A0A0C"/>
                                <Setter TargetName="MainBorder" Property="BorderBrush" Value="#FF18181C"/>
                                <Setter TargetName="Arrow" Property="Stroke" Value="#FF3A3A42"/>
                                <Setter Property="Foreground" Value="#FF5E5E68"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <Style TargetType="ComboBoxItem">
            <Setter Property="Foreground" Value="#FFE4E4EA"/>
            <Setter Property="Padding" Value="10,7"/>
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="ComboBoxItem">
                        <Border x:Name="b" Background="Transparent" CornerRadius="9" Padding="{TemplateBinding Padding}">
                            <ContentPresenter/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter TargetName="b" Property="Background" Value="#FF18181C"/>
                            </Trigger>
                            <Trigger Property="IsSelected" Value="True">
                                <Setter TargetName="b" Property="Background" Value="{DynamicResource PASoft}"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <!-- Scheda: superficie appena sopra il nero, con una sfumatura del colore
             della pagina nell'angolo in alto. Nessuna ombra: sul nero non si vede. -->
        <Style x:Key="Glass" TargetType="Border">
            <Setter Property="Background" Value="{DynamicResource PACard}"/>
            <Setter Property="BorderBrush" Value="#FF1A1A1F"/>
            <Setter Property="BorderThickness" Value="1"/>
            <Setter Property="CornerRadius" Value="22"/>
            <Setter Property="Padding" Value="20"/>
            <Setter Property="Margin" Value="7"/>
        </Style>

        <!-- Avvisi in cima alle pagine: fascia centrata con icona, diversa dalle schede delle impostazioni. -->
        <Style x:Key="NoticeBar" TargetType="Border">
            <Setter Property="BorderBrush" Value="#55E0A25E"/>
            <Setter Property="BorderThickness" Value="1"/>
            <Setter Property="CornerRadius" Value="14"/>
            <Setter Property="Padding" Value="24,12"/>
            <Setter Property="Margin" Value="7,0,7,8"/>
            <Setter Property="Background">
                <Setter.Value>
                    <LinearGradientBrush StartPoint="0,0" EndPoint="1,0">
                        <GradientStop Color="#08E0A25E" Offset="0"/>
                        <GradientStop Color="#1EE0A25E" Offset="0.5"/>
                        <GradientStop Color="#08E0A25E" Offset="1"/>
                    </LinearGradientBrush>
                </Setter.Value>
            </Setter>
        </Style>

        <Style x:Key="Bar" TargetType="Border">
            <Setter Property="Background" Value="#FF0A0A0C"/>
            <Setter Property="BorderBrush" Value="#FF1A1A1F"/>
            <Setter Property="BorderThickness" Value="1"/>
            <Setter Property="CornerRadius" Value="22"/>
        </Style>

        <Style x:Key="GlassInner" TargetType="Border">
            <Setter Property="Background" Value="#FF060607"/>
            <Setter Property="BorderBrush" Value="#FF1A1A1F"/>
            <Setter Property="BorderThickness" Value="1"/>
            <Setter Property="CornerRadius" Value="14"/>
            <Setter Property="Padding" Value="13"/>
        </Style>

        <Style x:Key="CardTitle" TargetType="TextBlock">
            <Setter Property="FontFamily" Value="Raleway, Segoe UI Variable Display, Segoe UI"/>
            <Setter Property="FontWeight" Value="Bold"/>
            <Setter Property="FontSize" Value="11.5"/>
            <Setter Property="Foreground" Value="{DynamicResource PA}"/>
            <Setter Property="Margin" Value="0,0,0,12"/>
        </Style>

        <Style x:Key="SubTitle" TargetType="TextBlock">
            <Setter Property="FontFamily" Value="Roboto, Segoe UI"/>
            <Setter Property="FontSize" Value="11.5"/>
            <Setter Property="Foreground" Value="#FF7E7E88"/>
            <Setter Property="TextWrapping" Value="Wrap"/>
            <Setter Property="LineHeight" Value="17"/>
        </Style>

        <Style x:Key="FieldLabel" TargetType="TextBlock">
            <Setter Property="FontFamily" Value="Roboto, Segoe UI"/>
            <Setter Property="FontSize" Value="12"/>
            <Setter Property="Foreground" Value="#FFC4C4CC"/>
            <Setter Property="VerticalAlignment" Value="Center"/>
        </Style>

        <Style x:Key="PrimaryBtn" TargetType="Button">
            <Setter Property="Foreground" Value="White"/>
            <Setter Property="FontFamily" Value="Raleway, Segoe UI Variable Display, Segoe UI"/>
            <Setter Property="FontWeight" Value="Bold"/>
            <Setter Property="FontSize" Value="14"/>
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border x:Name="b" Background="#FF1E90FF" CornerRadius="14" Padding="16,10">
                            <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter TargetName="b" Property="Background" Value="#FF4AA8FF"/>
                            </Trigger>
                            <Trigger Property="IsPressed" Value="True">
                                <Setter TargetName="b" Property="Background" Value="#FF0A6ED1"/>
                            </Trigger>
                            <Trigger Property="IsEnabled" Value="False">
                                <Setter TargetName="b" Property="Background" Value="#FF141417"/>
                                <Setter Property="Foreground" Value="#FF4E4E57"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <Style x:Key="GhostBtn" TargetType="Button">
            <Setter Property="Foreground" Value="#FFD4D4DA"/>
            <Setter Property="FontFamily" Value="Roboto, Segoe UI"/>
            <Setter Property="FontSize" Value="12.5"/>
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border x:Name="b" Background="#FF111114" BorderBrush="#FF232329" BorderThickness="1"
                                CornerRadius="12" Padding="14,9">
                            <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center">
                                <!-- Con l'arrotondamento dei pixel l'ultima lettera usciva dal
                                     riquadro del testo e veniva tagliata: il margine interno la
                                     tiene dentro. -->
                                <ContentPresenter.ContentTemplate>
                                    <DataTemplate>
                                        <TextBlock Text="{Binding}" Padding="4,0,6,0"/>
                                    </DataTemplate>
                                </ContentPresenter.ContentTemplate>
                            </ContentPresenter>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter TargetName="b" Property="Background" Value="#FF17171B"/>
                                <Setter TargetName="b" Property="BorderBrush" Value="{DynamicResource PA}"/>
                                <Setter Property="Foreground" Value="#FFFFFFFF"/>
                            </Trigger>
                            <Trigger Property="IsPressed" Value="True">
                                <Setter TargetName="b" Property="Background" Value="{DynamicResource PASoft}"/>
                            </Trigger>
                            <Trigger Property="IsEnabled" Value="False">
                                <Setter Property="Opacity" Value="0.35"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <!-- Pulsante con pallino colorato davanti al testo: il colore arriva da Tag. -->
        <Style x:Key="DotBtn" TargetType="Button">
            <Setter Property="Foreground" Value="#FFD4D4DA"/>
            <Setter Property="FontFamily" Value="Roboto, Segoe UI"/>
            <Setter Property="FontSize" Value="12.5"/>
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border x:Name="b" Background="#FF111114" BorderBrush="#FF232329" BorderThickness="1"
                                CornerRadius="12" Padding="13,9">
                            <StackPanel Orientation="Horizontal">
                                <Ellipse x:Name="dot" Width="8" Height="8" Margin="2,0,9,0" VerticalAlignment="Center"
                                         Fill="{Binding Tag, RelativeSource={RelativeSource TemplatedParent}}"/>
                                <TextBlock Text="{TemplateBinding Content}" Padding="0,0,6,0" VerticalAlignment="Center"/>
                            </StackPanel>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="Tag" Value="{x:Null}">
                                <Setter TargetName="dot" Property="Visibility" Value="Collapsed"/>
                            </Trigger>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter TargetName="b" Property="Background" Value="#FF17171B"/>
                                <Setter TargetName="b" Property="BorderBrush" Value="{DynamicResource PA}"/>
                                <Setter Property="Foreground" Value="#FFFFFFFF"/>
                            </Trigger>
                            <Trigger Property="IsPressed" Value="True">
                                <Setter TargetName="b" Property="Background" Value="{DynamicResource PASoft}"/>
                            </Trigger>
                            <Trigger Property="IsEnabled" Value="False">
                                <Setter Property="Opacity" Value="0.35"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <Style x:Key="NavHeader" TargetType="TextBlock">
            <Setter Property="FontFamily" Value="Raleway, Segoe UI"/>
            <Setter Property="FontSize" Value="10"/>
            <Setter Property="FontWeight" Value="Bold"/>
            <Setter Property="Foreground" Value="#FF55555F"/>
            <Setter Property="Margin" Value="14,12,0,4"/>
        </Style>

        <!-- Pulsante tonale per Reimposta predefiniti: arancio tenue, distinto dall'azione principale. -->
        <Style x:Key="UndoBtn" TargetType="Button" BasedOn="{StaticResource GhostBtn}">
            <Setter Property="Foreground" Value="#FFFFB86B"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border x:Name="b" Background="#1FFF9F43" BorderBrush="#4DFF9F43" BorderThickness="1"
                                CornerRadius="12" Padding="14,9">
                            <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center">
                                <!-- Con l'arrotondamento dei pixel l'ultima lettera usciva dal
                                     riquadro del testo e veniva tagliata: il margine interno la
                                     tiene dentro. -->
                                <ContentPresenter.ContentTemplate>
                                    <DataTemplate>
                                        <TextBlock Text="{Binding}" Padding="4,0,6,0"/>
                                    </DataTemplate>
                                </ContentPresenter.ContentTemplate>
                            </ContentPresenter>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter TargetName="b" Property="Background" Value="#33FF9F43"/>
                                <Setter TargetName="b" Property="BorderBrush" Value="#FFFF9F43"/>
                                <Setter Property="Foreground" Value="#FFFFD2A1"/>
                            </Trigger>
                            <Trigger Property="IsEnabled" Value="False">
                                <Setter TargetName="b" Property="Background" Value="#FF111114"/>
                                <Setter TargetName="b" Property="BorderBrush" Value="#FF1C1C21"/>
                                <Setter Property="Foreground" Value="#FF4E4E57"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <Style x:Key="LangBtn" TargetType="Button">
            <Setter Property="Foreground" Value="#FF8E8E98"/>
            <Setter Property="FontFamily" Value="Raleway, Segoe UI"/>
            <Setter Property="FontWeight" Value="Bold"/>
            <Setter Property="FontSize" Value="11"/>
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="Width" Value="34"/>
            <Setter Property="Height" Value="26"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border x:Name="b" Background="Transparent" CornerRadius="9">
                            <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter TargetName="b" Property="Background" Value="#FF18181C"/>
                                <Setter Property="Foreground" Value="#FFE4E4EA"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>
        <Style x:Key="LangBtnActive" TargetType="Button" BasedOn="{StaticResource LangBtn}">
            <Setter Property="Foreground" Value="#FF000000"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border Background="#FFF2F2F5" CornerRadius="9">
                            <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                        </Border>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <Style x:Key="CaptionBtn" TargetType="Button">
            <Setter Property="Width" Value="42"/>
            <Setter Property="Height" Value="32"/>
            <Setter Property="Cursor" Value="Arrow"/>
            <Setter Property="Foreground" Value="#FF8E8E98"/>
            <Setter Property="shell:WindowChrome.IsHitTestVisibleInChrome" Value="True"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border x:Name="b" Background="Transparent" CornerRadius="10">
                            <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter TargetName="b" Property="Background" Value="#FF18181C"/>
                                <Setter Property="Foreground" Value="#FFFFFFFF"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>
        <Style x:Key="CaptionBtnClose" TargetType="Button" BasedOn="{StaticResource CaptionBtn}">
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border x:Name="b" Background="Transparent" CornerRadius="10">
                            <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter TargetName="b" Property="Background" Value="#FFE5484D"/>
                                <Setter Property="Foreground" Value="#FFFFFFFF"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <!-- Barra di avanzamento: l'unico punto con piu' colori insieme. -->
        <Style TargetType="ProgressBar">
            <Setter Property="Background" Value="#FF141417"/>
            <Setter Property="BorderThickness" Value="0"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="ProgressBar">
                        <Grid>
                            <Border Background="{TemplateBinding Background}" CornerRadius="3"/>
                            <Grid ClipToBounds="True">
                                <Rectangle x:Name="PART_Track" Fill="Transparent"/>
                                <Rectangle x:Name="PART_Indicator" HorizontalAlignment="Left" RadiusX="3" RadiusY="3">
                                    <Rectangle.Fill>
                                        <LinearGradientBrush StartPoint="0,0" EndPoint="1,0">
                                            <GradientStop Color="#FF1E90FF" Offset="0"/>
                                            <GradientStop Color="#FFA78BFA" Offset="0.55"/>
                                            <GradientStop Color="#FFF472B6" Offset="1"/>
                                        </LinearGradientBrush>
                                    </Rectangle.Fill>
                                </Rectangle>
                            </Grid>
                        </Grid>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <Style TargetType="TextBox">
            <Setter Property="Foreground" Value="#FFFFFFFF"/>
            <Setter Property="CaretBrush" Value="{DynamicResource PA}"/>
            <Setter Property="FontFamily" Value="Consolas, Courier New"/>
            <Setter Property="FontSize" Value="12.5"/>
            <Setter Property="Padding" Value="10,7"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="TextBox">
                        <Border x:Name="b" Background="#FF111114" BorderBrush="#FF26262C"
                                BorderThickness="1" CornerRadius="12">
                            <ScrollViewer x:Name="PART_ContentHost" Margin="{TemplateBinding Padding}"
                                          VerticalAlignment="Center"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter TargetName="b" Property="BorderBrush" Value="{DynamicResource PA}"/>
                            </Trigger>
                            <Trigger Property="IsFocused" Value="True">
                                <Setter TargetName="b" Property="BorderBrush" Value="{DynamicResource PA}"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <Style x:Key="SoftSep" TargetType="Separator">
            <Setter Property="Background" Value="#FF1A1A1F"/>
            <Setter Property="Margin" Value="0,11"/>
            <Setter Property="Height" Value="1"/>
        </Style>

        <!-- Descrizione a comparsa delle voci. PA arriva dalle risorse della singola
             descrizione, impostate dal codice: il popup non vede quelle della pagina. -->
        <Style TargetType="ToolTip">
            <Setter Property="OverridesDefaultStyle" Value="True"/>
            <Setter Property="HasDropShadow" Value="False"/>
            <Setter Property="Foreground" Value="#FFE4E4EA"/>
            <Setter Property="FontFamily" Value="Roboto, Segoe UI"/>
            <Setter Property="FontSize" Value="12"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="ToolTip">
                        <Border Background="#F7131317" BorderBrush="#FF2A2A31" BorderThickness="1"
                                CornerRadius="12" MaxWidth="360" Margin="10">
                            <Border.Effect>
                                <DropShadowEffect BlurRadius="22" ShadowDepth="3" Opacity="0.55" Color="#000000"/>
                            </Border.Effect>
                            <Grid>
                                <Grid.ColumnDefinitions>
                                    <ColumnDefinition Width="Auto"/>
                                    <ColumnDefinition Width="*"/>
                                </Grid.ColumnDefinitions>
                                <Border Grid.Column="0" Width="3" CornerRadius="1.5" Margin="11,12,0,12"
                                        Background="{DynamicResource PA}"/>
                                <ContentPresenter Grid.Column="1" Margin="11,10,15,11">
                                    <ContentPresenter.ContentTemplate>
                                        <DataTemplate>
                                            <TextBlock Text="{Binding}" TextWrapping="Wrap" LineHeight="18"/>
                                        </DataTemplate>
                                    </ContentPresenter.ContentTemplate>
                                </ContentPresenter>
                            </Grid>
                        </Border>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

    </Window.Resources>

    <Border x:Name="shell" CornerRadius="0" BorderThickness="0">
        <Border.Background>
            <LinearGradientBrush StartPoint="0,0" EndPoint="1,1">
                <GradientStop Color="#FF0D0F16" Offset="0"/>
                <GradientStop Color="#FF060608" Offset="0.55"/>
                <GradientStop Color="#FF0B090E" Offset="1"/>
            </LinearGradientBrush>
        </Border.Background>

        <Grid>
            <!-- Alone morbido in alto: prende il colore della pagina aperta. -->
            <Border x:Name="glowPage" IsHitTestVisible="False">
                <Border.Background>
                    <RadialGradientBrush GradientOrigin="0.6,-0.1" Center="0.6,-0.1" RadiusX="0.8" RadiusY="0.9">
                        <GradientStop Color="#2EFF7A45" Offset="0"/>
                        <GradientStop Color="#00FF7A45" Offset="1"/>
                    </RadialGradientBrush>
                </Border.Background>
            </Border>
            <!-- Alone fisso in basso a sinistra, blu PcFixPro. -->
            <Border IsHitTestVisible="False">
                <Border.Background>
                    <RadialGradientBrush GradientOrigin="0,1.05" Center="0,1.05" RadiusX="0.6" RadiusY="0.7">
                        <GradientStop Color="#221E90FF" Offset="0"/>
                        <GradientStop Color="#001E90FF" Offset="1"/>
                    </RadialGradientBrush>
                </Border.Background>
            </Border>
            <Grid x:Name="rootScale">
                <Grid.RowDefinitions>
                    <RowDefinition Height="52"/>
                    <RowDefinition Height="*"/>
                </Grid.RowDefinitions>

                <Grid Grid.Row="0" Margin="16,0,10,0">
                    <Grid.ColumnDefinitions>
                        <ColumnDefinition Width="*"/>
                        <ColumnDefinition Width="Auto"/>
                        <ColumnDefinition Width="Auto"/>
                    </Grid.ColumnDefinitions>

                    <StackPanel Grid.Column="0" Orientation="Horizontal" VerticalAlignment="Center">
                        <Border Width="28" Height="28" CornerRadius="9" Background="#FF1E90FF" Margin="0,0,11,0">
                            <TextBlock Text="A" Foreground="White" FontFamily="Raleway, Segoe UI" FontWeight="Bold"
                                       FontSize="14" HorizontalAlignment="Center" VerticalAlignment="Center"/>
                        </Border>
                        <TextBlock Text="Tweak Andrew" FontFamily="Raleway, Segoe UI Variable Display, Segoe UI"
                                   FontSize="13.5" FontWeight="SemiBold" Foreground="#FFE4EBF2" VerticalAlignment="Center"/>
                        <TextBlock Text="v6.1" FontFamily="Roboto, Segoe UI" FontSize="11"
                                   Foreground="#FF6E7A88" VerticalAlignment="Center" Margin="9,1,0,0"/>
                    </StackPanel>

                    <ComboBox x:Name="cmbLang" Grid.Column="1" Width="138" Margin="0,0,10,0"
                              VerticalAlignment="Center" FontFamily="Segoe UI"
                              shell:WindowChrome.IsHitTestVisibleInChrome="True">
                        <ComboBoxItem Tag="it" Content="Italiano" IsSelected="True"/>
                        <ComboBoxItem Tag="en" Content="English"/>
                        <ComboBoxItem Tag="es" Content="Español"/>
                        <ComboBoxItem Tag="de" Content="Deutsch"/>
                        <ComboBoxItem Tag="fr" Content="Français"/>
                        <ComboBoxItem Tag="pl" Content="Polski"/>
                        <ComboBoxItem Tag="pt" Content="Português"/>
                        <ComboBoxItem Tag="ro" Content="Română"/>
                        <ComboBoxItem Tag="ru" Content="Русский"/>
                    </ComboBox>

                    <StackPanel Grid.Column="2" Orientation="Horizontal" VerticalAlignment="Center">
                        <Button x:Name="btnMin" Style="{StaticResource CaptionBtn}">
                            <Path Data="M0,0 L11,0" Stroke="{Binding Foreground, RelativeSource={RelativeSource AncestorType=Button}}" StrokeThickness="1.3"/>
                        </Button>
                        <Button x:Name="btnMax" Style="{StaticResource CaptionBtn}">
                            <Path Data="M0.5,0.5 L10.5,0.5 L10.5,10.5 L0.5,10.5 Z" Stroke="{Binding Foreground, RelativeSource={RelativeSource AncestorType=Button}}" StrokeThickness="1.3" Fill="Transparent"/>
                        </Button>
                        <Button x:Name="btnClose" Style="{StaticResource CaptionBtnClose}">
                            <Path Data="M0,0 L10,10 M10,0 L0,10" Stroke="{Binding Foreground, RelativeSource={RelativeSource AncestorType=Button}}" StrokeThickness="1.4" StrokeStartLineCap="Round" StrokeEndLineCap="Round"/>
                        </Button>
                    </StackPanel>
                </Grid>

                <Grid Grid.Row="1" Margin="14,4,14,14">
                    <Grid.ColumnDefinitions>
                        <ColumnDefinition Width="252"/>
                        <ColumnDefinition Width="*"/>
                    </Grid.ColumnDefinitions>

                    <Border Grid.Column="0" Background="Transparent" Padding="4,8,10,4" Margin="0,0,7,0">
                        <Grid>
                            <Grid.RowDefinitions>
                                <RowDefinition Height="Auto"/>
                                <RowDefinition Height="*"/>
                                <RowDefinition Height="Auto"/>
                            </Grid.RowDefinitions>

                            <StackPanel Grid.Row="0" Margin="6,4,6,10" Visibility="Collapsed">
                                <TextBlock Text="TWEAK ANDREW" FontFamily="Raleway, Segoe UI Variable Display, Segoe UI"
                                           FontSize="17" FontWeight="Bold" Foreground="#FFF2F2F5"/>
                                <TextBlock x:Name="lblSubtitle" Text="Ottimizzazione e controllo di Windows"
                                           Style="{StaticResource SubTitle}" Margin="0,3,0,0"/>
                            </StackPanel>

                            <ScrollViewer Grid.Row="1" VerticalScrollBarVisibility="Auto" Padding="0,0,4,0">
                            <StackPanel>
                                <RadioButton x:Name="tabHome" GroupName="Nav" Style="{StaticResource NavItem}" IsChecked="True"
                                             Content="Home" Margin="0,0,0,10"
                                             Tag="M3.5,11 L12,4 L20.5,11 M6,9.2 L6,20 L10,20 L10,14.5 L14,14.5 L14,20 L18,20 L18,9.2">
                                    <RadioButton.Resources>
                                        <SolidColorBrush x:Key="PA" Color="#FF1E90FF"/>
                                        <SolidColorBrush x:Key="PASoft" Color="#261E90FF"/>
                                        <LinearGradientBrush x:Key="PACard" StartPoint="0,0" EndPoint="0.7,1">
                                            <GradientStop Color="#161E90FF" Offset="0"/>
                                            <GradientStop Color="#0CFFFFFF" Offset="0.5"/>
                                        </LinearGradientBrush>
                                    </RadioButton.Resources>
                                </RadioButton>
                                <TextBlock x:Name="navGrpSystem" Text="SISTEMA" Style="{StaticResource NavHeader}" Margin="14,0,0,4"/>
                                <RadioButton x:Name="tabPerf" GroupName="Nav" Style="{StaticResource NavItem}"
                                             Content="Prestazioni"
                                             Tag="M13,2 L4,13.5 L10.5,13.5 L10,22 L19,10.5 L12.5,10.5 Z">
                                    <RadioButton.Resources>
                                        <SolidColorBrush x:Key="PA" Color="#FFFF7A45"/>
                                        <SolidColorBrush x:Key="PASoft" Color="#24FF7A45"/>
                                        <LinearGradientBrush x:Key="PACard" StartPoint="0,0" EndPoint="0.7,1">
                                            <GradientStop Color="#16FF7A45" Offset="0"/>
                                            <GradientStop Color="#0CFFFFFF" Offset="0.5"/>
                                        </LinearGradientBrush>
                                    </RadioButton.Resources>
                                </RadioButton>
                                <RadioButton x:Name="tabSched" GroupName="Nav" Style="{StaticResource NavItem}"
                                             Content="Priorita"
                                             Tag="M4,7 L20,7 M4,12 L20,12 M4,17 L20,17 M8,5 L8,9 M15,10 L15,14 M10,15 L10,19">
                                    <RadioButton.Resources>
                                        <SolidColorBrush x:Key="PA" Color="#FFA3E635"/>
                                        <SolidColorBrush x:Key="PASoft" Color="#24A3E635"/>
                                        <LinearGradientBrush x:Key="PACard" StartPoint="0,0" EndPoint="0.7,1">
                                            <GradientStop Color="#16A3E635" Offset="0"/>
                                            <GradientStop Color="#0CFFFFFF" Offset="0.5"/>
                                        </LinearGradientBrush>
                                    </RadioButton.Resources>
                                </RadioButton>
                                <RadioButton x:Name="tabPower" GroupName="Nav" Style="{StaticResource NavItem}"
                                             Content="Alimentazione"
                                             Tag="M12,3.5 A8.5,8.5 0 1 0 12.01,3.5 M12,2.5 L12,11">
                                    <RadioButton.Resources>
                                        <SolidColorBrush x:Key="PA" Color="#FFFFC53D"/>
                                        <SolidColorBrush x:Key="PASoft" Color="#24FFC53D"/>
                                        <LinearGradientBrush x:Key="PACard" StartPoint="0,0" EndPoint="0.7,1">
                                            <GradientStop Color="#16FFC53D" Offset="0"/>
                                            <GradientStop Color="#0CFFFFFF" Offset="0.5"/>
                                        </LinearGradientBrush>
                                    </RadioButton.Resources>
                                </RadioButton>
                                <RadioButton x:Name="tabGpu" GroupName="Nav" Style="{StaticResource NavItem}"
                                             Content="Scheda video"
                                             Tag="M3.5,7 L16,7 A3.5,3.5 0 0 1 16,16 L3.5,16 Z M7,11.5 A1.1,1.1 0 1 0 7.01,11.5 M10.5,11.5 A1.1,1.1 0 1 0 10.51,11.5 M6,16 L6,19.5 M13.5,16 L13.5,19.5">
                                    <RadioButton.Resources>
                                        <SolidColorBrush x:Key="PA" Color="#FF52E3A1"/>
                                        <SolidColorBrush x:Key="PASoft" Color="#2452E3A1"/>
                                        <LinearGradientBrush x:Key="PACard" StartPoint="0,0" EndPoint="0.7,1">
                                            <GradientStop Color="#1652E3A1" Offset="0"/>
                                            <GradientStop Color="#0CFFFFFF" Offset="0.5"/>
                                        </LinearGradientBrush>
                                    </RadioButton.Resources>
                                </RadioButton>
                                <RadioButton x:Name="tabStorage" GroupName="Nav" Style="{StaticResource NavItem}"
                                             Content="Archiviazione"
                                             Tag="M4,6.5 A8,2.8 0 1 0 20,6.5 A8,2.8 0 1 0 4,6.5 M4,6.5 L4,17.5 A8,2.8 0 0 0 20,17.5 L20,6.5 M4,12 A8,2.8 0 0 0 20,12">
                                    <RadioButton.Resources>
                                        <SolidColorBrush x:Key="PA" Color="#FF818CF8"/>
                                        <SolidColorBrush x:Key="PASoft" Color="#24818CF8"/>
                                        <LinearGradientBrush x:Key="PACard" StartPoint="0,0" EndPoint="0.7,1">
                                            <GradientStop Color="#16818CF8" Offset="0"/>
                                            <GradientStop Color="#0CFFFFFF" Offset="0.5"/>
                                        </LinearGradientBrush>
                                    </RadioButton.Resources>
                                </RadioButton>
                                <RadioButton x:Name="tabNet" GroupName="Nav" Style="{StaticResource NavItem}"
                                             Content="Rete"
                                             Tag="M3,8.5 A13,13 0 0 1 21,8.5 M6.5,12.5 A8,8 0 0 1 17.5,12.5 M10,16.5 A3.2,3.2 0 0 1 14,16.5">
                                    <RadioButton.Resources>
                                        <SolidColorBrush x:Key="PA" Color="#FF38BDF8"/>
                                        <SolidColorBrush x:Key="PASoft" Color="#2438BDF8"/>
                                        <LinearGradientBrush x:Key="PACard" StartPoint="0,0" EndPoint="0.7,1">
                                            <GradientStop Color="#1638BDF8" Offset="0"/>
                                            <GradientStop Color="#0CFFFFFF" Offset="0.5"/>
                                        </LinearGradientBrush>
                                    </RadioButton.Resources>
                                </RadioButton>
                                <TextBlock x:Name="navGrpPrivacy" Text="PRIVACY" Style="{StaticResource NavHeader}"/>
                                <RadioButton x:Name="tabPrivacy" GroupName="Nav" Style="{StaticResource NavItem}"
                                             Content="Privacy"
                                             Tag="M12,2.5 L19.5,5.8 V11.2 C19.5,16 16.4,20.2 12,21.5 C7.6,20.2 4.5,16 4.5,11.2 V5.8 Z">
                                    <RadioButton.Resources>
                                        <SolidColorBrush x:Key="PA" Color="#FFA78BFA"/>
                                        <SolidColorBrush x:Key="PASoft" Color="#24A78BFA"/>
                                        <LinearGradientBrush x:Key="PACard" StartPoint="0,0" EndPoint="0.7,1">
                                            <GradientStop Color="#16A78BFA" Offset="0"/>
                                            <GradientStop Color="#0CFFFFFF" Offset="0.5"/>
                                        </LinearGradientBrush>
                                    </RadioButton.Resources>
                                </RadioButton>
                                <RadioButton x:Name="tabPriv2" GroupName="Nav" Style="{StaticResource NavItem}"
                                             Content="Privacy avanzata"
                                             Tag="M12,2.5 L19.5,5.8 V11.2 C19.5,16 16.4,20.2 12,21.5 C7.6,20.2 4.5,16 4.5,11.2 V5.8 Z M8.5,11.5 L11,14 L15.5,9">
                                    <RadioButton.Resources>
                                        <SolidColorBrush x:Key="PA" Color="#FFC084FC"/>
                                        <SolidColorBrush x:Key="PASoft" Color="#24C084FC"/>
                                        <LinearGradientBrush x:Key="PACard" StartPoint="0,0" EndPoint="0.7,1">
                                            <GradientStop Color="#16C084FC" Offset="0"/>
                                            <GradientStop Color="#0CFFFFFF" Offset="0.5"/>
                                        </LinearGradientBrush>
                                    </RadioButton.Resources>
                                </RadioButton>
                                <TextBlock x:Name="navGrpCustom" Text="PERSONALIZZA" Style="{StaticResource NavHeader}"/>
                                <RadioButton x:Name="tabUi" GroupName="Nav" Style="{StaticResource NavItem}"
                                             Content="Interfaccia"
                                             Tag="M3.5,5 L20.5,5 L20.5,19 L3.5,19 Z M3.5,9 L20.5,9 M7.5,14 L13,14">
                                    <RadioButton.Resources>
                                        <SolidColorBrush x:Key="PA" Color="#FFF472B6"/>
                                        <SolidColorBrush x:Key="PASoft" Color="#24F472B6"/>
                                        <LinearGradientBrush x:Key="PACard" StartPoint="0,0" EndPoint="0.7,1">
                                            <GradientStop Color="#16F472B6" Offset="0"/>
                                            <GradientStop Color="#0CFFFFFF" Offset="0.5"/>
                                        </LinearGradientBrush>
                                    </RadioButton.Resources>
                                </RadioButton>
                                <RadioButton x:Name="tabExp" GroupName="Nav" Style="{StaticResource NavItem}"
                                             Content="Esplora file"
                                             Tag="M3.5,6.5 L9.5,6.5 L11.5,8.5 L20.5,8.5 L20.5,18.5 L3.5,18.5 Z">
                                    <RadioButton.Resources>
                                        <SolidColorBrush x:Key="PA" Color="#FF2DD4BF"/>
                                        <SolidColorBrush x:Key="PASoft" Color="#242DD4BF"/>
                                        <LinearGradientBrush x:Key="PACard" StartPoint="0,0" EndPoint="0.7,1">
                                            <GradientStop Color="#162DD4BF" Offset="0"/>
                                            <GradientStop Color="#0CFFFFFF" Offset="0.5"/>
                                        </LinearGradientBrush>
                                    </RadioButton.Resources>
                                </RadioButton>
                                <RadioButton x:Name="tabTask" GroupName="Nav" Style="{StaticResource NavItem}"
                                             Content="Start e barra"
                                             Tag="M3.5,4.5 L20.5,4.5 L20.5,19.5 L3.5,19.5 Z M3.5,15.5 L20.5,15.5 M7,17.5 L8,17.5 M11.5,17.5 L12.5,17.5 M16,17.5 L17,17.5">
                                    <RadioButton.Resources>
                                        <SolidColorBrush x:Key="PA" Color="#FF60A5FA"/>
                                        <SolidColorBrush x:Key="PASoft" Color="#2460A5FA"/>
                                        <LinearGradientBrush x:Key="PACard" StartPoint="0,0" EndPoint="0.7,1">
                                            <GradientStop Color="#1660A5FA" Offset="0"/>
                                            <GradientStop Color="#0CFFFFFF" Offset="0.5"/>
                                        </LinearGradientBrush>
                                    </RadioButton.Resources>
                                </RadioButton>
                                <RadioButton x:Name="tabNotif" GroupName="Nav" Style="{StaticResource NavItem}"
                                             Content="Notifiche e suoni"
                                             Tag="M6,16.5 L6,11 A6,6 0 0 1 18,11 L18,16.5 L19.5,18 L4.5,18 Z M10,20.5 L14,20.5">
                                    <RadioButton.Resources>
                                        <SolidColorBrush x:Key="PA" Color="#FFFB7185"/>
                                        <SolidColorBrush x:Key="PASoft" Color="#24FB7185"/>
                                        <LinearGradientBrush x:Key="PACard" StartPoint="0,0" EndPoint="0.7,1">
                                            <GradientStop Color="#16FB7185" Offset="0"/>
                                            <GradientStop Color="#0CFFFFFF" Offset="0.5"/>
                                        </LinearGradientBrush>
                                    </RadioButton.Resources>
                                </RadioButton>
                                <RadioButton x:Name="tabGame" GroupName="Nav" Style="{StaticResource NavItem}"
                                             Content="Giochi ed effetti"
                                             Tag="M7,8.5 L17,8.5 A4.5,4.5 0 0 1 17,17.5 L15.5,17.5 L13.5,15 L10.5,15 L8.5,17.5 L7,17.5 A4.5,4.5 0 0 1 7,8.5 Z M7,11.5 L7,14.5 M5.5,13 L8.5,13">
                                    <RadioButton.Resources>
                                        <SolidColorBrush x:Key="PA" Color="#FFE879F9"/>
                                        <SolidColorBrush x:Key="PASoft" Color="#24E879F9"/>
                                        <LinearGradientBrush x:Key="PACard" StartPoint="0,0" EndPoint="0.7,1">
                                            <GradientStop Color="#16E879F9" Offset="0"/>
                                            <GradientStop Color="#0CFFFFFF" Offset="0.5"/>
                                        </LinearGradientBrush>
                                    </RadioButton.Resources>
                                </RadioButton>
                                <TextBlock x:Name="navGrpWindows" Text="WINDOWS E APP" Style="{StaticResource NavHeader}"/>
                                <RadioButton x:Name="tabWin" GroupName="Nav" Style="{StaticResource NavItem}"
                                             Content="Windows e servizi"
                                             Tag="M4,5 L11,4 L11,11.5 L4,11.5 Z M13,3.7 L20,2.8 L20,11.5 L13,11.5 Z M4,13.5 L11,13.5 L11,20 L4,19 Z M13,13.5 L20,13.5 L20,21.2 L13,20.3 Z">
                                    <RadioButton.Resources>
                                        <SolidColorBrush x:Key="PA" Color="#FF94A3B8"/>
                                        <SolidColorBrush x:Key="PASoft" Color="#2494A3B8"/>
                                        <LinearGradientBrush x:Key="PACard" StartPoint="0,0" EndPoint="0.7,1">
                                            <GradientStop Color="#1694A3B8" Offset="0"/>
                                            <GradientStop Color="#0CFFFFFF" Offset="0.5"/>
                                        </LinearGradientBrush>
                                    </RadioButton.Resources>
                                </RadioButton>
                                <RadioButton x:Name="tabApps" GroupName="Nav" Style="{StaticResource NavItem}"
                                             Content="App e software"
                                             Tag="M4,4 L10,4 L10,10 L4,10 Z M14,4 L20,4 L20,10 L14,10 Z M4,14 L10,14 L10,20 L4,20 Z M14,17 L20,17 M17,14 L17,20">
                                    <RadioButton.Resources>
                                        <SolidColorBrush x:Key="PA" Color="#FFFDBA74"/>
                                        <SolidColorBrush x:Key="PASoft" Color="#24FDBA74"/>
                                        <LinearGradientBrush x:Key="PACard" StartPoint="0,0" EndPoint="0.7,1">
                                            <GradientStop Color="#16FDBA74" Offset="0"/>
                                            <GradientStop Color="#0CFFFFFF" Offset="0.5"/>
                                        </LinearGradientBrush>
                                    </RadioButton.Resources>
                                </RadioButton>
                                <RadioButton x:Name="tabTools" GroupName="Nav" Style="{StaticResource NavItem}"
                                             Content="Strumenti"
                                             Tag="M14.7,6.3 A4,4 0 0 0 9.3,11.7 L3.5,17.5 L6.5,20.5 L12.3,14.7 A4,4 0 0 0 17.7,9.3 L15,12 L12,9 Z">
                                    <RadioButton.Resources>
                                        <SolidColorBrush x:Key="PA" Color="#FF2DD4BF"/>
                                        <SolidColorBrush x:Key="PASoft" Color="#242DD4BF"/>
                                        <LinearGradientBrush x:Key="PACard" StartPoint="0,0" EndPoint="0.7,1">
                                            <GradientStop Color="#162DD4BF" Offset="0"/>
                                            <GradientStop Color="#0CFFFFFF" Offset="0.5"/>
                                        </LinearGradientBrush>
                                    </RadioButton.Resources>
                                </RadioButton>
                                <RadioButton x:Name="tabAdv" GroupName="Nav" Style="{StaticResource NavItem}"
                                             Content="Avanzate"
                                             Tag="M12,3 L12,21 M3,12 L21,12 M6.5,6.5 L17.5,17.5 M17.5,6.5 L6.5,17.5">
                                    <RadioButton.Resources>
                                        <SolidColorBrush x:Key="PA" Color="#FFF87171"/>
                                        <SolidColorBrush x:Key="PASoft" Color="#24F87171"/>
                                        <LinearGradientBrush x:Key="PACard" StartPoint="0,0" EndPoint="0.7,1">
                                            <GradientStop Color="#16F87171" Offset="0"/>
                                            <GradientStop Color="#0CFFFFFF" Offset="0.5"/>
                                        </LinearGradientBrush>
                                    </RadioButton.Resources>
                                </RadioButton>
                            </StackPanel>
                            </ScrollViewer>

                            <StackPanel Grid.Row="2" Margin="8,14,8,4">
                                <TextBlock x:Name="lblUiScale" Text="Scala interfaccia" Style="{StaticResource SubTitle}" Margin="0,0,0,6"/>
                                <ComboBox x:Name="cmbUiScale">
                                    <ComboBoxItem Content="100%" IsSelected="True"/>
                                    <ComboBoxItem Content="115%"/>
                                    <ComboBoxItem Content="130%"/>
                                    <ComboBoxItem Content="150%"/>
                                </ComboBox>
                                <Separator Style="{StaticResource SoftSep}" Margin="0,0,0,10"/>
                                <TextBlock Text="PcFixPro Italia" FontFamily="Raleway, Segoe UI" FontSize="11"
                                           FontWeight="SemiBold" Foreground="#FF7FC4E8"/>
                                <TextBlock Text="pcfixproitalia.it" Style="{StaticResource SubTitle}" FontSize="10.5" Margin="0,2,0,0"/>
                            </StackPanel>
                        </Grid>
                    </Border>

                    <Grid Grid.Column="1">
                        <Grid.RowDefinitions>
                            <RowDefinition Height="Auto"/>
                            <RowDefinition Height="*"/>
                            <RowDefinition Height="Auto"/>
                        </Grid.RowDefinitions>

                        <Grid Grid.Row="0" Margin="7,2,7,10">
                            <Grid.ColumnDefinitions>
                                <ColumnDefinition Width="*"/>
                                <ColumnDefinition Width="Auto"/>
                                <ColumnDefinition Width="Auto"/>
                                <ColumnDefinition Width="Auto"/>
                            </Grid.ColumnDefinitions>
                            <Border x:Name="pillActivity" Grid.Column="1" Visibility="Collapsed" Cursor="Hand"
                                    Background="#FF0A0A0C" BorderBrush="#FF26262C" BorderThickness="1" CornerRadius="14"
                                    Padding="14,7" Margin="0,0,10,0" VerticalAlignment="Center" MaxWidth="460">
                                <Grid>
                                    <Grid.RowDefinitions>
                                        <RowDefinition Height="Auto"/>
                                        <RowDefinition Height="Auto"/>
                                    </Grid.RowDefinitions>
                                    <Grid.ColumnDefinitions>
                                        <ColumnDefinition Width="Auto"/>
                                        <ColumnDefinition Width="*"/>
                                        <ColumnDefinition Width="Auto"/>
                                    </Grid.ColumnDefinitions>
                                    <Ellipse x:Name="dotActivity" Width="7" Height="7" Fill="#FF2ED3A7" Margin="0,0,9,0" VerticalAlignment="Center"/>
                                    <TextBlock x:Name="txtActivity" Grid.Column="1" Foreground="#FFE4E4EA" FontSize="12"
                                               TextTrimming="CharacterEllipsis" VerticalAlignment="Center"/>
                                    <TextBlock x:Name="txtActivityPct" Grid.Column="2" Foreground="#FF2ED3A7" FontSize="12" FontWeight="SemiBold"
                                               Margin="10,0,0,0" VerticalAlignment="Center"/>
                                    <ProgressBar x:Name="prgActivity" Grid.Row="1" Grid.ColumnSpan="3" Height="3" Margin="0,6,0,0"
                                                 Minimum="0" Maximum="100" Value="0"/>
                                </Grid>
                            </Border>
                            <StackPanel Grid.Column="0" Orientation="Horizontal" VerticalAlignment="Center">
                                <Border x:Name="pageAccent" Width="5" Height="26" CornerRadius="2.5" Background="#FFFF7A45" Margin="0,0,14,0"/>
                                <TextBlock x:Name="lblPageTitle" Text="Prestazioni"
                                           FontFamily="Raleway, Segoe UI Variable Display, Segoe UI"
                                           FontSize="26" FontWeight="Bold" Foreground="#FFF2F2F5" VerticalAlignment="Center"/>
                            </StackPanel>
                            <!-- «Rileva già attivi» sta qui e non nella barra in basso: con le lingue lunghe la barra andava su due righe. -->
                            <Button x:Name="btnDetectActive" Grid.Column="2" Style="{StaticResource GhostBtn}" Height="36" Margin="0,0,10,0"
                                    VerticalAlignment="Center" Content="Rileva già attivi"/>
                            <Border x:Name="pillSelected" Grid.Column="3" Background="#FF0A0A0C" BorderBrush="#FF1A1A1F" BorderThickness="1"
                                    CornerRadius="14" Padding="14,8" VerticalAlignment="Center">
                                <StackPanel Orientation="Horizontal">
                                    <TextBlock x:Name="lblSelected" Text="Selezionati:" Foreground="#FF7E7E88" FontSize="12"
                                               VerticalAlignment="Center" Margin="0,0,9,0"/>
                                    <!-- Con la scala al 130% l'arrotondamento tagliava la cifra: una
                                         larghezza minima e un filo di margine la tengono dentro. -->
                                    <TextBlock x:Name="txtSelectedCount" Text="0" Foreground="#FF2ED3A7"
                                               FontFamily="Raleway, Segoe UI" FontWeight="Bold" FontSize="15" VerticalAlignment="Center"
                                               MinWidth="20" Margin="0,0,3,0" TextAlignment="Right"/>
                                </StackPanel>
                            </Border>
                        </Grid>

                        <Grid Grid.Row="1">

                            <ScrollViewer x:Name="pageHome" VerticalScrollBarVisibility="Auto" Padding="0,0,6,0">
                                <ScrollViewer.Resources>
                                    <SolidColorBrush x:Key="PA" Color="#FF1E90FF"/>
                                    <SolidColorBrush x:Key="PASoft" Color="#261E90FF"/>
                                    <LinearGradientBrush x:Key="PACard" StartPoint="0,0" EndPoint="0.7,1">
                                        <GradientStop Color="#161E90FF" Offset="0"/>
                                        <GradientStop Color="#0CFFFFFF" Offset="0.5"/>
                                    </LinearGradientBrush>
                                </ScrollViewer.Resources>
                                <StackPanel x:Name="panHome">
                                    <TextBlock x:Name="lblHomeLoading" Text="Lettura dell'hardware..." Style="{StaticResource SubTitle}" Margin="10"/>
                                </StackPanel>
                            </ScrollViewer>

                            <ScrollViewer x:Name="pagePerf" Visibility="Collapsed" VerticalScrollBarVisibility="Auto" Padding="0,0,6,0">
                                <ScrollViewer.Resources>
                                    <SolidColorBrush x:Key="PA" Color="#FFFF7A45"/>
                                    <SolidColorBrush x:Key="PASoft" Color="#24FF7A45"/>
                                    <LinearGradientBrush x:Key="PACard" StartPoint="0,0" EndPoint="0.7,1">
                                        <GradientStop Color="#16FF7A45" Offset="0"/>
                                        <GradientStop Color="#0CFFFFFF" Offset="0.5"/>
                                    </LinearGradientBrush>
                                </ScrollViewer.Resources>
                                <Grid>
                                    <Grid.ColumnDefinitions>
                                        <ColumnDefinition Width="*"/>
                                        <ColumnDefinition Width="*"/>
                                        <ColumnDefinition Width="*"/>
                                    </Grid.ColumnDefinitions>

                                    <StackPanel Grid.Column="0">
                                        <Border Style="{StaticResource Glass}">
                                            <StackPanel>
                                                <TextBlock x:Name="ttlLatency" Text="LATENZA E SCHEDULING" Style="{StaticResource CardTitle}"/>
                                                <CheckBox x:Name="chkMMCSS" Content="MMCSS"/>
                                                <CheckBox x:Name="chkPriority" Content="Scheduling CPU"/>
                                                <CheckBox x:Name="chkKernelMem" Content="Memoria kernel"/>
                                                <CheckBox x:Name="chkKernelDpc" Content="Kernel e latenza DPC"/>
                                                <CheckBox x:Name="chkTimer" Content="Timer di sistema"/>
                                                <CheckBox x:Name="chkPowerThrottling" Content="Power Throttling"/>
                                                <CheckBox x:Name="chkUSBSuspend" Content="Sospensione selettiva USB"/>
                                                <CheckBox x:Name="chkNtfsPerf" Content="NTFS"/>
                                            </StackPanel>
                                        </Border>

                                        <Border Style="{StaticResource Glass}">
                                            <StackPanel>
                                                <TextBlock x:Name="ttlRam" Text="MEMORIA" Style="{StaticResource CardTitle}"/>
                                                <CheckBox x:Name="chkRamTweak" Content="Soglia SvcHost"/>
                                                <Grid Margin="8,10,0,0">
                                                    <Grid.ColumnDefinitions>
                                                        <ColumnDefinition Width="Auto"/>
                                                        <ColumnDefinition Width="*"/>
                                                    </Grid.ColumnDefinitions>
                                                    <TextBlock x:Name="lblRamInstalled" Grid.Column="0" Text="RAM installata:" Style="{StaticResource FieldLabel}" Margin="0,0,10,0"/>
                                                    <ComboBox x:Name="cmbRamAmount" Grid.Column="1" HorizontalAlignment="Left" Width="118">
                                                        <ComboBoxItem Content="2 GB"/>
                                                        <ComboBoxItem Content="4 GB"/>
                                                        <ComboBoxItem Content="8 GB"/>
                                                        <ComboBoxItem Content="16 GB"/>
                                                        <ComboBoxItem Content="32 GB" IsSelected="True"/>
                                                        <ComboBoxItem Content="64 GB"/>
                                                        <ComboBoxItem Content="128 GB"/>
                                                    </ComboBox>
                                                </Grid>
                                                <TextBlock x:Name="lblRamHint" Text="Rilevata automaticamente."
                                                           Style="{StaticResource SubTitle}" Margin="8,10,0,0"/>
                                            </StackPanel>
                                        </Border>
                                    </StackPanel>

                                    <StackPanel Grid.Column="1">
                                        <Border Style="{StaticResource Glass}">
                                            <StackPanel>
                                                <TextBlock x:Name="ttlGraphics" Text="GRAFICA E GIOCHI" Style="{StaticResource CardTitle}"/>
                                                <CheckBox x:Name="chkGameMode" Content="Modalita gioco"/>
                                                <CheckBox x:Name="chkFSO" Content="FSO"/>
                                                <CheckBox x:Name="chkGameDVR" Content="Game DVR"/>
                                                <CheckBox x:Name="chkHAGS" Content="HAGS"/>
                                                <CheckBox x:Name="chkVisualFX" Content="Effetti visivi"/>
                                                <Separator Style="{StaticResource SoftSep}"/>
                                                <CheckBox x:Name="chkApplyMPO" Content="Multiplane Overlay"/>
                                                <Grid Margin="8,8,0,0">
                                                    <Grid.ColumnDefinitions>
                                                        <ColumnDefinition Width="*"/>
                                                        <ColumnDefinition Width="Auto"/>
                                                    </Grid.ColumnDefinitions>
                                                <ComboBox x:Name="cmbMPO">
                                                    <ComboBoxItem x:Name="mpoOn" Content="Attivo"/>
                                                    <ComboBoxItem x:Name="mpoOff" Content="Disattivo" IsSelected="True"/>
                                                    <ComboBoxItem x:Name="mpoCompat" Content="Compatibile"/>
                                                </ComboBox>
                                                    <Button x:Name="btnMpoStar" Grid.Column="1" Style="{StaticResource StarBtn}" Margin="8,0,0,0"/>
                                                </Grid>
                                                <TextBlock x:Name="txtMpoCurrent" Style="{StaticResource SubTitle}" Margin="10,6,0,0"/>
                                            </StackPanel>
                                        </Border>

                                        <Border Style="{StaticResource Glass}">
                                            <StackPanel>
                                                <TextBlock x:Name="ttlCpu" Text="PROCESSORE" Style="{StaticResource CardTitle}"/>
                                                <TextBlock x:Name="txtCpuDetected" Style="{StaticResource SubTitle}" Margin="0,0,0,8"/>
                                                <CheckBox x:Name="chkCpuIntelBoostPol" Content="Intel: turbo senza freni di politica"/>
                                                <CheckBox x:Name="chkCpuIntelHybrid" Content="Intel ibridi: app in primo piano sui core P"/>
                                                <CheckBox x:Name="chkCpuAmdParking" Content="AMD Ryzen: nessun core parcheggiato"/>
                                            </StackPanel>
                                        </Border>

                                    </StackPanel>

                                    <StackPanel Grid.Column="2">
                                        <Border Style="{StaticResource Glass}">
                                            <Border.Background>
                                                <LinearGradientBrush StartPoint="0,0" EndPoint="0.7,1">
                                                    <GradientStop Color="#22E0A25E" Offset="0"/>
                                                    <GradientStop Color="#0AE0A25E" Offset="1"/>
                                                </LinearGradientBrush>
                                            </Border.Background>
                                            <StackPanel>
                                                <TextBlock x:Name="ttlRisky" Text="AVANZATE" Style="{StaticResource CardTitle}" Foreground="#FFE0A25E"/>
                                                <TextBlock x:Name="lblRiskyHint" Text="Escluse da Seleziona tutto."
                                                           Style="{StaticResource SubTitle}" Foreground="#FFD9A470" Margin="0,0,0,8"/>
                                                <CheckBox x:Name="chkVBS" Tag="risky" Content="VBS"/>
                                                <CheckBox x:Name="chkMitigations" Tag="risky" Content="Mitigazioni exploit"/>
                                                <CheckBox x:Name="chkCpuIdleOff" Tag="risky" Content="Processore sempre sveglio"/>
                                            </StackPanel>
                                        </Border>
                                    </StackPanel>
                                </Grid>
                            </ScrollViewer>

                            <ScrollViewer x:Name="pagePrivacy" Visibility="Collapsed" VerticalScrollBarVisibility="Auto" Padding="0,0,6,0">
                                <ScrollViewer.Resources>
                                    <SolidColorBrush x:Key="PA" Color="#FFA78BFA"/>
                                    <SolidColorBrush x:Key="PASoft" Color="#24A78BFA"/>
                                    <LinearGradientBrush x:Key="PACard" StartPoint="0,0" EndPoint="0.7,1">
                                        <GradientStop Color="#16A78BFA" Offset="0"/>
                                        <GradientStop Color="#0CFFFFFF" Offset="0.5"/>
                                    </LinearGradientBrush>
                                </ScrollViewer.Resources>
                                <Grid>
                                    <Grid.ColumnDefinitions>
                                        <ColumnDefinition Width="*"/>
                                        <ColumnDefinition Width="*"/>
                                        <ColumnDefinition Width="*"/>
                                    </Grid.ColumnDefinitions>

                                    <StackPanel Grid.Column="0">
                                        <Border Style="{StaticResource Glass}">
                                            <StackPanel>
                                                <TextBlock x:Name="ttlTelemetry" Text="TELEMETRIA" Style="{StaticResource CardTitle}" Foreground="#FF2ED3A7"/>
                                                <CheckBox x:Name="chkTelemetry" Content="Telemetria"/>
                                                <CheckBox x:Name="chkTelemetryTasks" Content="Attivita pianificate"/>
                                                <CheckBox x:Name="chkActivityHistory" Content="Cronologia"/>
                                                <CheckBox x:Name="chkLocationTracking" Content="Posizione"/>
                                                <CheckBox x:Name="chkAdvertisingID" Content="ID pubblicita"/>
                                                <CheckBox x:Name="chkTailoredExp" Content="Esperienze personalizzate"/>
                                                <CheckBox x:Name="chkFeedback" Content="Feedback"/>
                                                <CheckBox x:Name="chkErrorReporting" Content="Segnalazione errori"/>
                                                <CheckBox x:Name="chkInkingTyping" Content="Input penna"/>
                                                <CheckBox x:Name="chkWiFiSense" Content="Wi-Fi Sense"/>
                                            </StackPanel>
                                        </Border>
                                    </StackPanel>

                                    <StackPanel Grid.Column="1">
                                        <Border Style="{StaticResource Glass}">
                                            <StackPanel>
                                                <TextBlock x:Name="ttlContent" Text="SUGGERIMENTI" Style="{StaticResource CardTitle}" Foreground="#FF2ED3A7"/>
                                                <CheckBox x:Name="chkConsumerFeatures" Content="App suggerite"/>
                                                <CheckBox x:Name="chkStoreSearch" Content="Ricerca Store"/>
                                                <CheckBox x:Name="chkSuggestedContent" Content="Contenuti suggeriti"/>
                                                <CheckBox x:Name="chkLockScreenAds" Content="Spotlight"/>
                                                <CheckBox x:Name="chkStartBing" Content="Bing nel menu Start"/>
                                                <CheckBox x:Name="chkStartRecs" Content="Suggerimenti Start"/>
                                                <CheckBox x:Name="chkStartTracking" Content="Tracciamento app"/>
                                                <CheckBox x:Name="chkFolderDiscovery" Content="Tipo cartella"/>
                                            </StackPanel>
                                        </Border>
                                        <Border Style="{StaticResource Glass}">
                                            <StackPanel>
                                                <TextBlock x:Name="ttlMsApps" Text="APP MICROSOFT" Style="{StaticResource CardTitle}" Foreground="#FF2ED3A7"/>
                                                <CheckBox x:Name="chkWindowsAI" Content="Copilot e Recall"/>
                                                <CheckBox x:Name="chkEdgeDebloat" Content="Edge"/>
                                                <CheckBox x:Name="chkOneDriveRemove" Content="OneDrive"/>
                                                <CheckBox x:Name="chkOutlookNew" Content="Nuovo Outlook"/>
                                            </StackPanel>
                                        </Border>
                                    </StackPanel>

                                    <StackPanel Grid.Column="2">
                                        <Border Style="{StaticResource Glass}">
                                            <StackPanel>
                                                <TextBlock x:Name="ttlServices" Text="SERVIZI" Style="{StaticResource CardTitle}" Foreground="#FF2ED3A7"/>
                                                <CheckBox x:Name="chkServicesManual" Content="Servizi non essenziali"/>
                                                <CheckBox x:Name="chkDeliveryOpt" Content="Ottimizzazione recapito"/>
                                                <CheckBox x:Name="chkBitLocker" Content="BitLocker"/>
                                                <CheckBox x:Name="chkWPBT" Content="WPBT"/>
                                                <CheckBox x:Name="chkBackgroundApps" Content="App in background"/>
                                                <CheckBox x:Name="chkTeredo" Content="Teredo"/>
                                                <CheckBox x:Name="chkRDPWarnings" Content="Avvisi RDP"/>
                                                <CheckBox x:Name="chkRemoteAssistance" Content="Assistenza remota"/>
                                                <CheckBox x:Name="chkCompanionApps" Content="App companion"/>
                                                <CheckBox x:Name="chkDriverUpdates" Content="Driver da Windows Update"/>
                                            </StackPanel>
                                        </Border>
                                    </StackPanel>
                                </Grid>
                            </ScrollViewer>

                            <ScrollViewer x:Name="pageUi" Visibility="Collapsed" VerticalScrollBarVisibility="Auto" Padding="0,0,6,0">
                                <ScrollViewer.Resources>
                                    <SolidColorBrush x:Key="PA" Color="#FFF472B6"/>
                                    <SolidColorBrush x:Key="PASoft" Color="#24F472B6"/>
                                    <LinearGradientBrush x:Key="PACard" StartPoint="0,0" EndPoint="0.7,1">
                                        <GradientStop Color="#16F472B6" Offset="0"/>
                                        <GradientStop Color="#0CFFFFFF" Offset="0.5"/>
                                    </LinearGradientBrush>
                                </ScrollViewer.Resources>
                                <Grid>
                                    <Grid.ColumnDefinitions>
                                        <ColumnDefinition Width="*"/>
                                        <ColumnDefinition Width="*"/>
                                        <ColumnDefinition Width="*"/>
                                    </Grid.ColumnDefinitions>

                                    <StackPanel Grid.Column="0">
                                        <Border Style="{StaticResource Glass}">
                                            <StackPanel>
                                                <TextBlock x:Name="ttlSystemUi" Text="SISTEMA" Style="{StaticResource CardTitle}" Foreground="#FFE0A25E"/>
                                                <CheckBox x:Name="chkDarkTheme" Content="Tema scuro"/>
                                                <CheckBox x:Name="chkFileExt" Content="Estensioni dei file"/>
                                                <CheckBox x:Name="chkLongPaths" Content="Percorsi lunghi"/>
                                                <CheckBox x:Name="chkClassicMenu" Content="Menu classico"/>
                                                <CheckBox x:Name="chkExplorerThisPC" Content="Questo PC"/>
                                                <CheckBox x:Name="chkRemove3D" Content="Oggetti 3D"/>
                                                <CheckBox x:Name="chkRecycleConfirm" Content="Conferma eliminazione"/>
                                                <CheckBox x:Name="chkMenuDelay" Content="Ritardo menu"/>
                                            </StackPanel>
                                        </Border>

                                        <Border Style="{StaticResource Glass}">
                                            <StackPanel>
                                                <TextBlock x:Name="ttlStart" Text="MENU START" Style="{StaticResource CardTitle}" Foreground="#FFE0A25E"/>
                                                <CheckBox x:Name="chkStartMorePins" Content="Piu spazio ai collegamenti"/>
                                                <CheckBox x:Name="chkStartHideRec" Content="Nascondi la sezione Consigliati"/>
                                                <CheckBox x:Name="chkStartNoWeb" Content="Niente siti consigliati"/>
                                                <CheckBox x:Name="chkStartNoAccount" Content="Niente notifiche account"/>
                                            </StackPanel>
                                        </Border>
                                    </StackPanel>

                                    <StackPanel Grid.Column="1">
                                        <Border Style="{StaticResource Glass}">
                                            <StackPanel>
                                                <TextBlock x:Name="ttlTaskbar" Text="BARRA APPLICAZIONI" Style="{StaticResource CardTitle}" Foreground="#FFE0A25E"/>
                                                <CheckBox x:Name="chkTaskbarCenter" Content="Icone al centro"/>
                                                <CheckBox x:Name="chkTaskbarSearch" Content="Icona Cerca"/>
                                                <CheckBox x:Name="chkTaskbarTaskView" Content="Visualizzazione attivita"/>
                                                <CheckBox x:Name="chkTaskbarWidgets" Content="Widget"/>
                                                <CheckBox x:Name="chkTaskbarChat" Content="Chat"/>
                                                <CheckBox x:Name="chkTaskbarEndTask" Content="Termina attivita"/>
                                                <CheckBox x:Name="chkBatteryPct" Content="Percentuale batteria"/>
                                                <CheckBox x:Name="chkSettingsHome" Content="Pagina Impostazioni"/>
                                                <CheckBox x:Name="chkWindowSnapping" Content="Affiancamento finestre"/>
                                            </StackPanel>
                                        </Border>
                                    </StackPanel>

                                    <StackPanel Grid.Column="2">
                                        <Border Style="{StaticResource Glass}">
                                            <StackPanel>
                                                <TextBlock x:Name="ttlInput" Text="INPUT" Style="{StaticResource CardTitle}" Foreground="#FFE0A25E"/>
                                                <CheckBox x:Name="chkMouseAccel" Content="Accelerazione mouse"/>
                                                <CheckBox x:Name="chkNumLock" Content="Bloc Num"/>
                                                <CheckBox x:Name="chkStickyKeys" Content="Tasti permanenti"/>
                                                <CheckBox x:Name="chkScrollbars" Content="Barre di scorrimento"/>
                                            </StackPanel>
                                        </Border>
                                        <Border Style="{StaticResource Glass}">
                                            <StackPanel>
                                                <TextBlock x:Name="ttlLock" Text="ACCESSO" Style="{StaticResource CardTitle}" Foreground="#FFE0A25E"/>
                                                <CheckBox x:Name="chkLockScreen" Content="Schermata di blocco"/>
                                                <CheckBox x:Name="chkLogonBlur" Content="Sfocatura accesso"/>
                                                <CheckBox x:Name="chkBSODVerbose" Content="Schermata blu dettagliata"/>
                                                <CheckBox x:Name="chkLogonVerbose" Content="Accesso dettagliato"/>
                                            </StackPanel>
                                        </Border>

                                        <Border Style="{StaticResource Glass}">
                                            <StackPanel>
                                                <TextBlock x:Name="ttlFeat" Text="FUNZIONI NASCOSTE" Style="{StaticResource CardTitle}" Foreground="#FFE0A25E"/>
                                                <TextBlock x:Name="lblFeatHint" Style="{StaticResource SubTitle}" Margin="0,0,0,10"
                                                           Text="Attiva o disattiva una funzione di Windows tramite il suo numero identificativo, come fa ViVeTool. Ogni build ha i suoi numeri."/>
                                                <TextBlock x:Name="lblFeatId" Text="Numero della funzione" Style="{StaticResource FieldLabel}" Margin="0,0,0,6"/>
                                                <TextBox x:Name="txtFeatId" Margin="0,0,0,8"/>
                                                <ComboBox x:Name="cmbFeatState" Margin="0,0,0,8">
                                                    <ComboBoxItem x:Name="featOn" Content="Attiva" IsSelected="True"/>
                                                    <ComboBoxItem x:Name="featOff" Content="Disattiva"/>
                                                    <ComboBoxItem x:Name="featReset" Content="Torna al predefinito"/>
                                                </ComboBox>
                                                <Button x:Name="btnFeatApply" Content="Applica" Style="{StaticResource GhostBtn}" Margin="0,0,0,8"/>
                                                <Button x:Name="btnFeatList" Content="Elenca le modifiche attive" Style="{StaticResource GhostBtn}" Margin="0,0,0,10"/>
                                                <Border Style="{StaticResource GlassInner}" Padding="11,9">
                                                    <TextBlock x:Name="txtFeatList" Text="Nessuna modifica elencata."
                                                               FontFamily="Consolas, Courier New" FontSize="11.5"
                                                               Foreground="#FFC9D4E0" TextWrapping="Wrap" LineHeight="17"/>
                                                </Border>
                                            </StackPanel>
                                        </Border>
                                    </StackPanel>
                                </Grid>
                            </ScrollViewer>

                            <Grid x:Name="pageNet" Visibility="Collapsed">
                                <Grid.Resources>
                                    <SolidColorBrush x:Key="PA" Color="#FF38BDF8"/>
                                    <SolidColorBrush x:Key="PASoft" Color="#2438BDF8"/>
                                    <LinearGradientBrush x:Key="PACard" StartPoint="0,0" EndPoint="0.7,1">
                                        <GradientStop Color="#1638BDF8" Offset="0"/>
                                        <GradientStop Color="#0CFFFFFF" Offset="0.5"/>
                                    </LinearGradientBrush>
                                </Grid.Resources>
                                <Grid.RowDefinitions>
                                    <RowDefinition Height="Auto"/>
                                    <RowDefinition Height="*"/>
                                </Grid.RowDefinitions>

                                <Border Grid.Row="0" Style="{StaticResource Glass}" Margin="7,0,7,3" Padding="16,13">
                                    <Grid>
                                        <Grid.ColumnDefinitions>
                                            <ColumnDefinition Width="*"/>
                                            <ColumnDefinition Width="Auto"/>
                                        </Grid.ColumnDefinitions>
                                        <StackPanel Grid.Column="0">
                                            <CheckBox x:Name="chkApplyNetwork" Content="Applica le impostazioni di rete" FontSize="13"/>
                                            <TextBlock x:Name="lblNetHint" Text="Senza questa spunta nulla viene modificato."
                                                       Style="{StaticResource SubTitle}" Margin="36,2,0,0"/>
                                        </StackPanel>
                                        <Button Grid.Column="1" x:Name="btnFlushDns" Content="Svuota cache DNS" Style="{StaticResource GhostBtn}" VerticalAlignment="Center"/>
                                    </Grid>
                                </Border>

                                <Grid Grid.Row="1">
                                    <Grid.ColumnDefinitions>
                                        <ColumnDefinition Width="*"/>
                                        <ColumnDefinition Width="*"/>
                                    </Grid.ColumnDefinitions>

                                    <Border Grid.Column="0" Style="{StaticResource Glass}">
                                        <Grid>
                                            <Grid.RowDefinitions>
                                                <RowDefinition Height="Auto"/>
                                                <RowDefinition Height="*"/>
                                            </Grid.RowDefinitions>
                                            <StackPanel Grid.Row="0">
                                                <TextBlock x:Name="ttlTcpProfile" Text="PROFILO TCP" Style="{StaticResource CardTitle}"/>
                                                <WrapPanel Margin="0,0,0,4">
                                                    <RadioButton x:Name="radTcpOptimal" Content="Ottimale" IsChecked="True" GroupName="TcpPreset"/>
                                                    <RadioButton x:Name="radTcpDefault" Content="Predefinito" GroupName="TcpPreset"/>
                                                    <RadioButton x:Name="radTcpCurrent" Content="Profilo attuale" GroupName="TcpPreset"/>
                                                    <RadioButton x:Name="radTcpCustom" Content="Personalizzato" GroupName="TcpPreset"/>
                                                </WrapPanel>
                                                <Separator Style="{StaticResource SoftSep}"/>
                                                <TextBlock x:Name="ttlTcpIp" Text="TCP / IP" Style="{StaticResource CardTitle}"/>
                                            </StackPanel>
                                            <ScrollViewer Grid.Row="1" VerticalScrollBarVisibility="Auto">
                                                <StackPanel>
                                                    <Grid Margin="0,5">
                                                        <TextBlock x:Name="lblAutoTuning" Text="Auto-Tuning:" Style="{StaticResource FieldLabel}"/>
                                                        <ComboBox x:Name="cmbTcpAutoTuning" HorizontalAlignment="Right" Width="178">
                                                            <ComboBoxItem Content="normal" IsSelected="True"/>
                                                            <ComboBoxItem Content="disabled"/>
                                                            <ComboBoxItem Content="experimental"/>
                                                            <ComboBoxItem Content="highlyrestricted"/>
                                                            <ComboBoxItem Content="restricted"/>
                                                        </ComboBox>
                                                    </Grid>
                                                    <Grid Margin="0,5">
                                                        <TextBlock x:Name="lblHeuristics" Text="Euristiche:" Style="{StaticResource FieldLabel}"/>
                                                        <ComboBox x:Name="cmbScalingHeuristics" HorizontalAlignment="Right" Width="178">
                                                            <ComboBoxItem Content="disabled" IsSelected="True"/>
                                                            <ComboBoxItem Content="enabled"/>
                                                        </ComboBox>
                                                    </Grid>
                                                    <Grid Margin="0,5">
                                                        <TextBlock x:Name="lblCongestion" Text="Congestione:" Style="{StaticResource FieldLabel}"/>
                                                        <ComboBox x:Name="cmbCongestionControl" HorizontalAlignment="Right" Width="178">
                                                            <ComboBoxItem Content="CUBIC" IsSelected="True"/>
                                                            <ComboBoxItem Content="CTCP"/>
                                                            <ComboBoxItem Content="NewReno"/>
                                                            <ComboBoxItem Content="none"/>
                                                        </ComboBox>
                                                    </Grid>
                                                    <Grid Margin="0,5">
                                                        <TextBlock x:Name="lblRss" Text="RSS:" Style="{StaticResource FieldLabel}"/>
                                                        <ComboBox x:Name="cmbRSS" HorizontalAlignment="Right" Width="178">
                                                            <ComboBoxItem Content="enabled" IsSelected="True"/>
                                                            <ComboBoxItem Content="disabled"/>
                                                        </ComboBox>
                                                    </Grid>
                                                    <Grid Margin="0,5">
                                                        <TextBlock x:Name="lblRsc" Text="RSC:" Style="{StaticResource FieldLabel}"/>
                                                        <ComboBox x:Name="cmbRSC" HorizontalAlignment="Right" Width="178">
                                                            <ComboBoxItem Content="disabled" IsSelected="True"/>
                                                            <ComboBoxItem Content="enabled"/>
                                                        </ComboBox>
                                                    </Grid>
                                                    <Grid Margin="0,5">
                                                        <TextBlock x:Name="lblTtl" Text="TTL:" Style="{StaticResource FieldLabel}"/>
                                                        <ComboBox x:Name="cmbTTL" HorizontalAlignment="Right" Width="178">
                                                            <ComboBoxItem Content="64" IsSelected="True"/>
                                                            <ComboBoxItem Content="128"/>
                                                        </ComboBox>
                                                    </Grid>
                                                    <Grid Margin="0,5">
                                                        <TextBlock x:Name="lblEcn" Text="ECN:" Style="{StaticResource FieldLabel}"/>
                                                        <ComboBox x:Name="cmbECN" HorizontalAlignment="Right" Width="178">
                                                            <ComboBoxItem Content="enabled" IsSelected="True"/>
                                                            <ComboBoxItem Content="disabled"/>
                                                        </ComboBox>
                                                    </Grid>
                                                    <Grid Margin="0,5">
                                                        <TextBlock x:Name="lblTimestamps" Text="Timestamp:" Style="{StaticResource FieldLabel}"/>
                                                        <ComboBox x:Name="cmbTimestamps" HorizontalAlignment="Right" Width="178">
                                                            <ComboBoxItem Content="disabled" IsSelected="True"/>
                                                            <ComboBoxItem Content="enabled"/>
                                                        </ComboBox>
                                                    </Grid>
                                                </StackPanel>
                                            </ScrollViewer>
                                        </Grid>
                                    </Border>

                                    <Border Grid.Column="1" Style="{StaticResource Glass}">
                                        <Grid>
                                            <Grid.RowDefinitions>
                                                <RowDefinition Height="Auto"/>
                                                <RowDefinition Height="*"/>
                                            </Grid.RowDefinitions>
                                            <StackPanel Grid.Row="0">
                                                <TextBlock x:Name="ttlDns" Text="DNS" Style="{StaticResource CardTitle}"/>
                                                <CheckBox x:Name="chkApplyDns" Content="Cambia i server DNS"/>
                                                <ComboBox x:Name="cmbDnsProvider" Margin="8,8,0,0">
                                                    <ComboBoxItem Content="Cloudflare (1.1.1.1 / 1.0.0.1)" IsSelected="True"/>
                                                    <ComboBoxItem Content="Google (8.8.8.8 / 8.8.4.4)"/>
                                                    <ComboBoxItem Content="Quad9 (9.9.9.9 / 149.112.112.112)"/>
                                                    <ComboBoxItem Content="OpenDNS (208.67.222.222 / 208.67.220.220)"/>
                                                    <ComboBoxItem Content="AdGuard (94.140.14.14 / 94.140.15.15)"/>
                                                    <ComboBoxItem x:Name="dnsAuto" Content="Automatico (DHCP)"/>
                                                </ComboBox>
                                                <Separator Style="{StaticResource SoftSep}"/>
                                                <TextBlock x:Name="ttlNetAdv" Text="RETE AVANZATA" Style="{StaticResource CardTitle}"/>
                                            </StackPanel>
                                            <ScrollViewer Grid.Row="1" VerticalScrollBarVisibility="Auto">
                                                <StackPanel>
                                                    <Grid Margin="0,5">
                                                        <TextBlock x:Name="lblThrottling" Text="Throttling:" Style="{StaticResource FieldLabel}"/>
                                                        <ComboBox x:Name="cmbNetThrottling" HorizontalAlignment="Right" Width="178">
                                                            <ComboBoxItem Content="disabled: ffffffff" IsSelected="True"/>
                                                            <ComboBoxItem Content="default: 10"/>
                                                        </ComboBox>
                                                    </Grid>
                                                    <Grid Margin="0,5">
                                                        <TextBlock x:Name="lblResponsiveness" Text="Responsiveness:" Style="{StaticResource FieldLabel}"/>
                                                        <ComboBox x:Name="cmbSysResponsiveness" HorizontalAlignment="Right" Width="178">
                                                            <ComboBoxItem Content="optimal: 10" IsSelected="True"/>
                                                            <ComboBoxItem Content="gaming: 0"/>
                                                            <ComboBoxItem Content="default: 20"/>
                                                        </ComboBox>
                                                    </Grid>
                                                    <Grid Margin="0,5">
                                                        <TextBlock x:Name="lblNagle" Text="Nagle:" Style="{StaticResource FieldLabel}"/>
                                                        <ComboBox x:Name="cmbNagle" HorizontalAlignment="Right" Width="178">
                                                            <ComboBoxItem Content="disabled: 1" IsSelected="True"/>
                                                            <ComboBoxItem Content="enabled: 0"/>
                                                        </ComboBox>
                                                    </Grid>
                                                    <Grid Margin="0,5">
                                                        <TextBlock x:Name="lblHostPriority" Text="Risoluzione host:" Style="{StaticResource FieldLabel}"/>
                                                        <ComboBox x:Name="cmbHostPriority" HorizontalAlignment="Right" Width="178">
                                                            <ComboBoxItem Content="Optimal (4-5-6-7)" IsSelected="True"/>
                                                            <ComboBoxItem Content="Default Windows"/>
                                                        </ComboBox>
                                                    </Grid>
                                                    <Grid Margin="0,5">
                                                        <TextBlock x:Name="lblNetMem" Text="LargeSystemCache:" Style="{StaticResource FieldLabel}"/>
                                                        <ComboBox x:Name="cmbNetMemAlloc" HorizontalAlignment="Right" Width="178">
                                                            <ComboBoxItem Content="Optimal (1 / 3)" IsSelected="True"/>
                                                            <ComboBoxItem Content="Default Windows"/>
                                                        </ComboBox>
                                                    </Grid>
                                                    <Grid Margin="0,5">
                                                        <TextBlock x:Name="lblPortAlloc" Text="Porte dinamiche:" Style="{StaticResource FieldLabel}"/>
                                                        <ComboBox x:Name="cmbPortAlloc" HorizontalAlignment="Right" Width="178">
                                                            <ComboBoxItem Content="Max 65534 / Wait 30s" IsSelected="True"/>
                                                            <ComboBoxItem Content="Default Windows"/>
                                                        </ComboBox>
                                                    </Grid>
                                                    <Grid Margin="0,5">
                                                        <TextBlock x:Name="lblMaxConn" Text="Connessioni:" Style="{StaticResource FieldLabel}"/>
                                                        <ComboBox x:Name="cmbMaxConn" HorizontalAlignment="Right" Width="178">
                                                            <ComboBoxItem Content="10 Connections" IsSelected="True"/>
                                                            <ComboBoxItem Content="16 Connections"/>
                                                            <ComboBoxItem Content="Default (2)"/>
                                                        </ComboBox>
                                                    </Grid>
                                                    <Separator Style="{StaticResource SoftSep}"/>
                                                    <CheckBox x:Name="chkNetPowerSave" Content="Risparmio schede di rete"/>
                                                    <CheckBox x:Name="chkDisableIPv6" Tag="risky" Content="IPv6"/>
                                                    <CheckBox x:Name="chkIPv4Pref" Tag="risky" Content="IPv4 prima di IPv6"/>
                                                </StackPanel>
                                            </ScrollViewer>
                                        </Grid>
                                    </Border>
                                </Grid>
                            </Grid>

                            <Grid x:Name="pageStorage" Visibility="Collapsed">
                                <Grid.Resources>
                                    <SolidColorBrush x:Key="PA" Color="#FF818CF8"/>
                                    <SolidColorBrush x:Key="PASoft" Color="#24818CF8"/>
                                    <LinearGradientBrush x:Key="PACard" StartPoint="0,0" EndPoint="0.7,1">
                                        <GradientStop Color="#16818CF8" Offset="0"/>
                                        <GradientStop Color="#0CFFFFFF" Offset="0.5"/>
                                    </LinearGradientBrush>
                                </Grid.Resources>
                                <Grid.ColumnDefinitions>
                                    <ColumnDefinition Width="1.3*"/>
                                    <ColumnDefinition Width="*"/>
                                </Grid.ColumnDefinitions>

                                <Border Grid.Column="0" Style="{StaticResource Glass}">
                                    <Grid>
                                        <Grid.RowDefinitions>
                                            <RowDefinition Height="Auto"/>
                                            <RowDefinition Height="*"/>
                                            <RowDefinition Height="Auto"/>
                                        </Grid.RowDefinitions>

                                        <Grid Grid.Row="0">
                                            <Grid.ColumnDefinitions>
                                                <ColumnDefinition Width="*"/>
                                                <ColumnDefinition Width="Auto"/>
                                            </Grid.ColumnDefinitions>
                                            <StackPanel Grid.Column="0">
                                                <TextBlock x:Name="ttlDrives" Text="UNITA RILEVATE" Style="{StaticResource CardTitle}" Margin="0,0,0,4"/>
                                                <TextBlock x:Name="lblDrivesHint" Text="Dischi installati e spazio libero di ogni volume."
                                                           Style="{StaticResource SubTitle}" Margin="0,0,0,12"/>
                                            </StackPanel>
                                            <Button Grid.Column="1" x:Name="btnDetectStorage" Content="Aggiorna" Style="{StaticResource GhostBtn}" VerticalAlignment="Top"/>
                                        </Grid>

                                        <ScrollViewer Grid.Row="1" VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Disabled" Margin="0,0,0,14" Padding="0,0,6,0" MinHeight="90">
                                            <StackPanel x:Name="panDisks"/>
                                        </ScrollViewer>

                                        <StackPanel Grid.Row="2">
                                            <TextBlock x:Name="ttlProfile" Text="PROFILO DA APPLICARE" Style="{StaticResource CardTitle}" Margin="0,0,0,5"/>
                                            <TextBlock x:Name="lblProfileHint" Text="" TextWrapping="Wrap"
                                                       Style="{StaticResource SubTitle}" Margin="0,0,0,10"/>
                                            <StackPanel Orientation="Horizontal">
                                                <RadioButton x:Name="radStorageSSD" Content="SSD / NVMe" GroupName="StorageProfile"/>
                                                <RadioButton x:Name="radStorageHDD" Content="HDD meccanico" GroupName="StorageProfile"/>
                                            </StackPanel>
                                            <TextBlock x:Name="lblProfileQueued" Style="{StaticResource SubTitle}" Margin="0,8,0,0" TextWrapping="Wrap"
                                                       Text="Scegli un profilo: entra tra le modifiche da applicare. Un secondo clic lo toglie."/>
                                            <CheckBox x:Name="chkStorageProfile" Content="Profilo" Visibility="Collapsed"/>
                                        </StackPanel>
                                    </Grid>
                                </Border>

                                <!-- Colonna destra con la sua barra: a finestra bassa le schede restano raggiungibili. -->
                                <ScrollViewer Grid.Column="1" VerticalScrollBarVisibility="Auto" Padding="0,0,6,0">
                                <StackPanel>
                                    <Border Style="{StaticResource Glass}">
                                        <StackPanel>
                                            <TextBlock x:Name="ttlNow" Text="AZIONI IMMEDIATE" Style="{StaticResource CardTitle}"/>
                                            <TextBlock x:Name="lblNowHint" Text="Partono subito al clic."
                                                       Style="{StaticResource SubTitle}" Margin="0,0,0,12"/>
                                            <Button x:Name="btnTrimNow" Content="Esegui TRIM ora" Style="{StaticResource GhostBtn}" Margin="0,0,0,8"/>
                                            <Button x:Name="btnOptimizeNow" Content="Ottimizza C:" Style="{StaticResource GhostBtn}" Margin="0,0,0,8"/>
                                            <Button x:Name="btnEmptyRecycle" Content="Svuota il Cestino" Style="{StaticResource GhostBtn}" Margin="0,0,0,8"/>
                                            <Button x:Name="btnCleanUpdates" Content="Cache Windows Update" Style="{StaticResource GhostBtn}"/>
                                        </StackPanel>
                                    </Border>

                                    <Border Style="{StaticResource Glass}">
                                        <StackPanel>
                                            <TextBlock x:Name="ttlMaintenance" Text="MANUTENZIONE" Style="{StaticResource CardTitle}"/>
                                            <CheckBox x:Name="chkDiskCleanup" Content="Pulizia Disco e DISM"/>
                                            <CheckBox x:Name="chkTempCleanup" Content="File temporanei"/>
                                            <CheckBox x:Name="chkSmartChkdsk" Content="CHKDSK intelligente"/>
                                        </StackPanel>
                                    </Border>

                                    <Border Style="{StaticResource Glass}">
                                        <StackPanel>
                                            <TextBlock x:Name="ttlSpace" Text="SPAZIO" Style="{StaticResource CardTitle}"/>
                                            <CheckBox x:Name="chkStorageSense" Content="Sensore memoria"/>
                                            <CheckBox x:Name="chkReservedStorage" Content="Spazio riservato"/>
                                        </StackPanel>
                                    </Border>
                                </StackPanel>
                                </ScrollViewer>
                            </Grid>

                            <!-- In cima l'avviso; a sinistra i piani in una colonna che scorre da sola, a destra il resto, una scheda sotto l'altra. -->
                            <Grid x:Name="pagePower" Visibility="Collapsed">
                                <Grid.Resources>
                                    <SolidColorBrush x:Key="PA" Color="#FFFFC53D"/>
                                    <SolidColorBrush x:Key="PASoft" Color="#24FFC53D"/>
                                    <LinearGradientBrush x:Key="PACard" StartPoint="0,0" EndPoint="0.7,1">
                                        <GradientStop Color="#16FFC53D" Offset="0"/>
                                        <GradientStop Color="#0CFFFFFF" Offset="0.5"/>
                                    </LinearGradientBrush>
                                </Grid.Resources>
                                <Grid.ColumnDefinitions>
                                    <ColumnDefinition Width="*"/>
                                    <ColumnDefinition Width="1.3*"/>
                                </Grid.ColumnDefinitions>
                                <Grid.RowDefinitions>
                                    <RowDefinition Height="Auto"/>
                                    <RowDefinition Height="*"/>
                                </Grid.RowDefinitions>

                                <Border Grid.ColumnSpan="2" Style="{StaticResource NoticeBar}">
                                    <StackPanel HorizontalAlignment="Center" MaxWidth="980">
                                        <StackPanel Orientation="Horizontal" HorizontalAlignment="Center" Margin="0,0,0,4">
                                            <Border Width="18" Height="18" CornerRadius="9" Background="#FFE0A25E" Margin="0,0,8,0" VerticalAlignment="Center">
                                                <TextBlock Text="!" FontWeight="Bold" FontSize="12" Foreground="#FF1A1208" HorizontalAlignment="Center" VerticalAlignment="Center"/>
                                            </Border>
                                            <TextBlock x:Name="ttlPlanWarn" Text="PRIMA DI PROVARE" Style="{StaticResource CardTitle}" Foreground="#FFE0A25E" Margin="0" VerticalAlignment="Center"/>
                                        </StackPanel>
                                        <TextBlock x:Name="lblPlanWarn" Style="{StaticResource SubTitle}" Foreground="#FFD9B48A" TextAlignment="Center"
                                                   Text="I piani della sezione Da testare arrivano da terze parti. Provane uno alla volta e torna su Bilanciato se il computer diventa instabile."/>
                                    </StackPanel>
                                </Border>

                                <Grid Grid.Row="1" Grid.Column="0">
                                    <Grid.RowDefinitions>
                                        <RowDefinition Height="*"/>
                                    </Grid.RowDefinitions>
                                    <Border Grid.Row="0" Style="{StaticResource Glass}">
                                        <Grid>
                                            <Grid.RowDefinitions>
                                                <RowDefinition Height="Auto"/>
                                                <RowDefinition Height="*"/>
                                            </Grid.RowDefinitions>
                                                <Grid Grid.Row="0" Margin="0,0,0,14">
                                                    <Grid.ColumnDefinitions>
                                                        <ColumnDefinition Width="*"/>
                                                        <ColumnDefinition Width="Auto"/>
                                                    </Grid.ColumnDefinitions>
                                                    <StackPanel Grid.Column="0" Margin="0,0,12,0">
                                                        <TextBlock x:Name="ttlPlans" Text="PIANI DI ALIMENTAZIONE" Style="{StaticResource CardTitle}" Margin="0,0,0,6"/>
                                                        <Border Style="{StaticResource GlassInner}" Padding="12,9">
                                                            <TextBlock x:Name="lblPowerActive" Text="Piano attivo:" Style="{StaticResource SubTitle}" Foreground="{DynamicResource PA}"/>
                                                        </Border>
                                                    </StackPanel>
                                                    <StackPanel Grid.Column="1" VerticalAlignment="Bottom">
                                                        <Button x:Name="btnRefreshPlans" Content="Aggiorna" Style="{StaticResource GhostBtn}" Margin="0,0,0,7"/>
                                                        <Button x:Name="btnRemoveTestPlans" Content="Rimuovi piani di prova" Style="{StaticResource GhostBtn}"/>
                                                    </StackPanel>
                                                </Grid>
                                            <ScrollViewer Grid.Row="1" VerticalScrollBarVisibility="Auto" Padding="0,0,8,0">
                                                <StackPanel x:Name="panPlans"/>
                                            </ScrollViewer>
                                        </Grid>
                                    </Border>
                                </Grid>

                                <ScrollViewer Grid.Row="1" Grid.Column="1" VerticalScrollBarVisibility="Auto" Padding="0,0,6,0">
                                    <StackPanel>
                                    <StackPanel Margin="7,0,7,4">
                                        <TextBlock x:Name="ttlPowerAdv" Text="IMPOSTAZIONI DEL PIANO IN USO" Style="{StaticResource CardTitle}" Margin="0,0,0,4"/>
                                        <TextBlock x:Name="lblPowerAdvHint" Style="{StaticResource SubTitle}" TextWrapping="Wrap"
                                                   Text="Cambiano subito il piano attivo, sia con l'alimentatore sia a batteria: non serve premere Applica. Se attivi un altro piano, valgono le impostazioni di quello."/>
                                    </StackPanel>
                                    <Grid x:Name="catPower"/>
                                        <Border Style="{StaticResource Glass}">
                                            <StackPanel>
                                                <TextBlock x:Name="ttlSleep" Text="RISPARMIO E SOSPENSIONE" Style="{StaticResource CardTitle}"/>
                                                <TextBlock x:Name="lblSleepHint" Text="Si applicano con il pulsante Applica."
                                                           Style="{StaticResource SubTitle}" Margin="0,0,0,10"/>
                                                <CheckBox x:Name="chkFastStartup" Content="Avvio rapido"/>
                                                <CheckBox x:Name="chkHibernation" Content="Ibernazione"/>
                                                <CheckBox x:Name="chkS0Sleep" Content="Standby moderno"/>
                                                <CheckBox x:Name="chkS3Sleep" Content="Sospensione S3"/>
                                                <CheckBox x:Name="chkDiskNoSleep" Content="Dischi e SSD sempre attivi"/>
                                            </StackPanel>
                                        </Border>

                                        <Border Style="{StaticResource Glass}">
                                            <StackPanel>
                                                <TextBlock x:Name="ttlShutdownMenu" Text="MENU ARRESTA" Style="{StaticResource CardTitle}"/>
                                                <TextBlock x:Name="lblShutdownHint" Style="{StaticResource SubTitle}" Margin="0,0,0,10"
                                                           Text="Valgono subito, senza Applica. Le impostazioni del piano energetico non vengono toccate."/>
                                                <CheckBox x:Name="chkMenuSleep" Tag="live" Content="Sospendi nel menu Arresta"/>
                                                <CheckBox x:Name="chkMenuHibernate" Tag="live" Content="Iberna nel menu Arresta"/>
                                            </StackPanel>
                                        </Border>
                                    </StackPanel>
                                </ScrollViewer>
                            </Grid>

                            <ScrollViewer x:Name="pageGpu" Visibility="Collapsed" VerticalScrollBarVisibility="Auto" Padding="0,0,6,0">
                                <ScrollViewer.Resources>
                                    <SolidColorBrush x:Key="PA" Color="#FF52E3A1"/>
                                    <SolidColorBrush x:Key="PASoft" Color="#2452E3A1"/>
                                    <LinearGradientBrush x:Key="PACard" StartPoint="0,0" EndPoint="0.7,1">
                                        <GradientStop Color="#1652E3A1" Offset="0"/>
                                        <GradientStop Color="#0CFFFFFF" Offset="0.5"/>
                                    </LinearGradientBrush>
                                </ScrollViewer.Resources>
                                <Grid>
                                    <Grid.ColumnDefinitions>
                                        <ColumnDefinition Width="*"/>
                                        <ColumnDefinition Width="*"/>
                                        <ColumnDefinition Width="*"/>
                                    </Grid.ColumnDefinitions>

                                    <StackPanel Grid.Column="0">
                                        <Border Style="{StaticResource Glass}">
                                            <StackPanel>
                                                <Grid>
                                                    <Grid.ColumnDefinitions>
                                                        <ColumnDefinition Width="*"/>
                                                        <ColumnDefinition Width="Auto"/>
                                                    </Grid.ColumnDefinitions>
                                                    <TextBlock Grid.Column="0" x:Name="ttlGpuDetected" Text="SCHEDA RILEVATA" Style="{StaticResource CardTitle}"/>
                                                    <Button Grid.Column="1" x:Name="btnDetectGpu" Content="Aggiorna" Style="{StaticResource GhostBtn}" VerticalAlignment="Top" Margin="0,-4,0,0"/>
                                                </Grid>
                                                <Border Style="{StaticResource GlassInner}">
                                                    <TextBlock x:Name="txtGpuDetected" Text="Rilevamento in corso..."
                                                               Foreground="{DynamicResource PA}" FontFamily="Consolas, Courier New"
                                                               FontSize="11.5" TextWrapping="Wrap" LineHeight="17"/>
                                                </Border>
                                                <TextBlock x:Name="lblGpuHint" Style="{StaticResource SubTitle}" Margin="0,12,0,0"
                                                           Text="Qui si alleggerisce il driver già installato: telemetria, servizi accessori e avvii automatici."/>
                                            </StackPanel>
                                        </Border>

                                        <Border Style="{StaticResource Glass}">
                                            <StackPanel>
                                                <TextBlock x:Name="ttlGpuCommon" Text="IMPOSTAZIONI COMUNI" Style="{StaticResource CardTitle}"/>
                                                <CheckBox x:Name="chkGpuTdr" Content="TDR - timeout più lungo"/>
                                                <CheckBox x:Name="chkGpuMsi" Tag="risky" Content="Interrupt MSI per la GPU"/>
                                            </StackPanel>
                                        </Border>

                                        <Border Style="{StaticResource Glass}">
                                            <StackPanel>
                                                <TextBlock x:Name="ttlShader" Text="CACHE SHADER" Style="{StaticResource CardTitle}"/>
                                                <TextBlock x:Name="lblShaderHint" Style="{StaticResource SubTitle}" Margin="0,0,0,10"
                                                           Text="Gli shader già compilati dai giochi. Svuotarla libera spazio e risolve artefatti dopo un cambio driver. Il primo avvio di ogni gioco sarà più lento, poi torna normale."/>
                                                <Border Style="{StaticResource GlassInner}" Padding="11,9" Margin="0,0,0,10">
                                                    <TextBlock x:Name="txtShaderSize" Text="Spazio non ancora calcolato."
                                                               FontFamily="Consolas, Courier New" FontSize="11.5"
                                                               Foreground="{DynamicResource PA}" TextWrapping="Wrap" LineHeight="17"/>
                                                </Border>
                                                <Button x:Name="btnShaderScan" Content="Calcola spazio occupato" Style="{StaticResource GhostBtn}" Margin="0,0,0,8"/>
                                                <Button x:Name="btnShaderClear" Content="Svuota cache shader" Style="{StaticResource GhostBtn}"/>
                                            </StackPanel>
                                        </Border>
                                    </StackPanel>

                                    <StackPanel Grid.Column="1">
                                        <Border Style="{StaticResource Glass}">
                                            <StackPanel>
                                                <TextBlock x:Name="ttlNvidia" Text="NVIDIA" Style="{StaticResource CardTitle}" Foreground="#FF7ED957"/>
                                                <TextBlock x:Name="lblNvidiaHint" Style="{StaticResource SubTitle}" Margin="0,0,0,10"
                                                           Text="Voci ignorate se la scheda non è NVIDIA."/>
                                                <CheckBox x:Name="chkNvTelemetry" Content="Telemetria NVIDIA"/>
                                                <CheckBox x:Name="chkNvGfe" Content="GeForce Experience in background"/>
                                                <CheckBox x:Name="chkNvPerfMode" Content="Gestione energia su prestazioni massime"/>
                                                <CheckBox x:Name="chkNvUpdates" Content="Controllo aggiornamenti driver NVIDIA"/>
                                            </StackPanel>
                                        </Border>

                                        <Border Style="{StaticResource Glass}">
                                            <StackPanel>
                                                <TextBlock x:Name="ttlNvProfile" Text="NVIDIA: PRESTAZIONI DEL PROFILO" Style="{StaticResource CardTitle}" Foreground="#FF7ED957"/>
                                                <TextBlock x:Name="lblNvProfileHint" Style="{StaticResource SubTitle}" Margin="0,0,0,10"
                                                           Text="Scritte nel profilo globale del driver, come nel Pannello di controllo NVIDIA."/>
                                                <CheckBox x:Name="chkNvP2" Content="CUDA: niente stato P2 forzato"/>
                                                <CheckBox x:Name="chkNvDrsPower" Content="Gestione energia: prestazioni massime"/>
                                                <CheckBox x:Name="chkNvLowLatency" Content="Modalita bassa latenza: attiva"/>
                                                <CheckBox x:Name="chkNvThreaded" Content="Ottimizzazione thread attiva"/>
                                                <CheckBox x:Name="chkNvTexPerf" Content="Filtro texture: prestazioni elevate"/>
                                                <CheckBox x:Name="chkNvAniso" Content="Ottimizzazione campioni anisotropici"/>
                                                <CheckBox x:Name="chkNvShaderCache" Content="Cache shader illimitata"/>
                                                <CheckBox x:Name="chkNvNoAnsel" Content="Ansel spento"/>
                                            </StackPanel>
                                        </Border>

                                        <Border Style="{StaticResource Glass}">
                                            <StackPanel>
                                                <TextBlock x:Name="ttlNvReg" Text="NVIDIA: REGISTRO DEL DRIVER" Style="{StaticResource CardTitle}" Foreground="#FF7ED957"/>
                                                <CheckBox x:Name="chkNvDisplayPower" Content="Risparmio energetico del display spento"/>
                                                <CheckBox x:Name="chkNvHdcp" Tag="risky" Content="HDCP spento"/>
                                                <CheckBox x:Name="chkNvPreempt" Tag="risky" Content="Prelazione dei calcoli spenta"/>
                                                <CheckBox x:Name="chkNvDynPstate" Tag="risky" Content="Frequenze sempre al massimo (P0)"/>
                                                <CheckBox x:Name="chkNvLatency" Tag="risky" Content="Pacchetto latenza del driver"/>
                                            </StackPanel>
                                        </Border>
                                    </StackPanel>

                                    <StackPanel Grid.Column="2">
                                        <Border Style="{StaticResource Glass}">
                                            <StackPanel>
                                                <TextBlock x:Name="ttlAmd" Text="AMD RADEON" Style="{StaticResource CardTitle}" Foreground="#FFFF6B6B"/>
                                                <TextBlock x:Name="lblAmdHint" Style="{StaticResource SubTitle}" Margin="0,0,0,10"
                                                           Text="Voci ignorate se la scheda non è AMD."/>
                                                <CheckBox x:Name="chkAmdUx" Content="Programma esperienza utente AMD"/>
                                                <CheckBox x:Name="chkAmdBloat" Content="Servizi e avvii automatici AMD"/>
                                                <CheckBox x:Name="chkAmdUlps" Content="Prestazioni massime (ULPS spento)"/>
                                                <CheckBox x:Name="chkAmdAntiLag" Content="Anti-Lag attivo"/>
                                                <CheckBox x:Name="chkAmdShaderCache" Content="Cache shader sempre attiva"/>
                                                <CheckBox x:Name="chkAmdTexPerf" Content="Filtro texture: prestazioni"/>
                                                <CheckBox x:Name="chkAmdTess" Content="Tassellatura limitata dal driver"/>
                                                <CheckBox x:Name="chkAmdFlipQueue" Content="Coda dei fotogrammi a 1"/>
                                                <CheckBox x:Name="chkAmdNoFrtc" Content="Limite fotogrammi del driver spento"/>
                                                <CheckBox x:Name="chkAmdStutter" Content="Modalita stutter spenta"/>
                                                <CheckBox x:Name="chkAmdAspm" Content="Risparmio PCIe della scheda spento"/>
                                                <CheckBox x:Name="chkAmdPowerGating" Tag="risky" Content="Power gating spento"/>
                                                <CheckBox x:Name="chkAmdDma" Tag="risky" Content="Copie DMA e scrittura a blocchi"/>
                                                <CheckBox x:Name="chkAmdPreempt" Tag="risky" Content="Prelazione dei calcoli spenta"/>
                                            </StackPanel>
                                        </Border>

                                        <Border Style="{StaticResource Glass}">
                                            <StackPanel>
                                                <TextBlock x:Name="ttlIntelGpu" Text="INTEL GRAPHICS" Style="{StaticResource CardTitle}" Foreground="#FF7FC4E8"/>
                                                <CheckBox x:Name="chkIntelBloat" Content="Servizi accessori Intel Graphics"/>
                                                <CheckBox x:Name="chkIntelTelemetry" Content="Telemetria Intel spenta"/>
                                                <CheckBox x:Name="chkIntelGfxPower" Content="Piano grafico Intel: prestazioni massime"/>
                                                <CheckBox x:Name="chkIntelDpst" Content="Risparmio energetico del display (DPST) spento"/>
                                            </StackPanel>
                                        </Border>
                                    </StackPanel>
                                </Grid>
                            </ScrollViewer>
                            <ScrollViewer x:Name="pageAdv" Visibility="Collapsed" VerticalScrollBarVisibility="Auto" Padding="0,0,6,0">
                                <ScrollViewer.Resources>
                                    <SolidColorBrush x:Key="PA" Color="#FFF87171"/>
                                    <SolidColorBrush x:Key="PASoft" Color="#24F87171"/>
                                    <LinearGradientBrush x:Key="PACard" StartPoint="0,0" EndPoint="0.7,1">
                                        <GradientStop Color="#16F87171" Offset="0"/>
                                        <GradientStop Color="#0CFFFFFF" Offset="0.5"/>
                                    </LinearGradientBrush>
                                </ScrollViewer.Resources>
                                <StackPanel>
                                <Border Style="{StaticResource NoticeBar}">
                                    <StackPanel HorizontalAlignment="Center" MaxWidth="980">
                                        <StackPanel Orientation="Horizontal" HorizontalAlignment="Center" Margin="0,0,0,4">
                                            <Border Width="18" Height="18" CornerRadius="9" Background="#FFE0A25E" Margin="0,0,8,0" VerticalAlignment="Center">
                                                <TextBlock Text="!" FontWeight="Bold" FontSize="12" Foreground="#FF1A1208" HorizontalAlignment="Center" VerticalAlignment="Center"/>
                                            </Border>
                                            <TextBlock x:Name="ttlAdvIntro" Text="PRIMA DI PROCEDERE" Style="{StaticResource CardTitle}" Foreground="#FFE0A25E" Margin="0" VerticalAlignment="Center"/>
                                        </StackPanel>
                                        <TextBlock x:Name="lblAdvIntro" Style="{StaticResource SubTitle}" Foreground="#FFD9B48A" TextAlignment="Center"
                                                   Text="Queste voci tolgono parti di Windows che la maggior parte dei computer non usa. Guadagno reale su macchine dedicate a giochi o lavoro, ma qualcosa smette di funzionare: leggi la descrizione di ogni voce. Crea un punto di ripristino prima di applicare, e riavvia dopo."/>
                                    </StackPanel>
                                </Border>
                                <!-- Colonne per argomento: aggiornamenti e manutenzione, servizi e memoria, avvio, periferiche, app e sicurezza. -->
                                <Grid>
                                    <Grid.ColumnDefinitions>
                                        <ColumnDefinition Width="*"/>
                                        <ColumnDefinition Width="*"/>
                                        <ColumnDefinition Width="*"/>
                                    </Grid.ColumnDefinitions>

                                    <StackPanel Grid.Column="0">
                                        <Border Style="{StaticResource Glass}">
                                            <StackPanel>
                                                <TextBlock x:Name="ttlWu" Text="WINDOWS UPDATE" Style="{StaticResource CardTitle}"/>
                                                <TextBlock x:Name="lblWuHint" Style="{StaticResource SubTitle}" Margin="0,0,0,10"
                                                           Text="Scegli un profilo: entra tra le modifiche da applicare. Un secondo clic lo toglie."/>
                                                <StackPanel x:Name="panWuProfiles"/>
                                                <TextBlock x:Name="txtWuCurrent" Style="{StaticResource SubTitle}" Margin="2,0,0,8"/>
                                                <CheckBox x:Name="chkWuProfile" Content="Profilo di Windows Update" Visibility="Collapsed"/>
                                                <CheckBox x:Name="chkWuNoStore" Content="Aggiornamento automatico delle app dello Store"/>
                                            </StackPanel>
                                        </Border>

                                        <Border Style="{StaticResource Glass}">
                                            <StackPanel>
                                                <TextBlock x:Name="ttlTasks" Text="ATTIVITA PIANIFICATE" Style="{StaticResource CardTitle}"/>
                                                <CheckBox x:Name="chkTaskExtra" Content="Attivita non essenziali di Microsoft"/>
                                                <CheckBox x:Name="chkTaskMaint" Content="Manutenzione automatica notturna"/>
                                                <CheckBox x:Name="chkTaskDefrag" Tag="risky" Content="Ottimizzazione unita pianificata — rischioso: su SSD manda anche il TRIM"/>
                                            </StackPanel>
                                        </Border>

                                        <Border Style="{StaticResource Glass}">
                                            <StackPanel>
                                                <TextBlock x:Name="ttlAdvExplorer" Text="ESPLORA FILE" Style="{StaticResource CardTitle}"/>
                                                <TextBlock x:Name="lblAdvExplorerHint" Style="{StaticResource SubTitle}" Margin="0,0,0,10"
                                                           Text="Mostrano file che Windows tiene nascosti per non farli cancellare per sbaglio. Fuori da «Seleziona tutto»."/>
                                                <CheckBox x:Name="chkHiddenFiles" Content="Mostra file nascosti"/>
                                            </StackPanel>
                                        </Border>
                                    </StackPanel>

                                    <StackPanel Grid.Column="1">
                                        <Border Style="{StaticResource Glass}">
                                            <StackPanel>
                                                <TextBlock x:Name="ttlSvc" Text="SERVIZI DA FERMARE" Style="{StaticResource CardTitle}"/>
                                                <TextBlock x:Name="lblSvcHint" Style="{StaticResource SubTitle}" Margin="0,0,0,10"
                                                           Text="I servizi assenti vengono ignorati. Si possono sempre riattivare da services.msc."/>
                                                <CheckBox x:Name="chkSvcSysMain" Content="SysMain — precaricamento delle app in memoria"/>
                                                <CheckBox x:Name="chkSvcDiag" Content="Diagnostica e tracciamento eventi"/>
                                                <CheckBox x:Name="chkSvcErrors" Content="Segnalazione errori Windows"/>
                                                <CheckBox x:Name="chkSvcPca" Content="Assistente compatibilità programmi"/>
                                                <CheckBox x:Name="chkSvcDiscovery" Content="Rilevamento dispositivi in rete (UPnP, SSDP)"/>
                                                <CheckBox x:Name="chkSvcSensors" Content="Sensori e geolocalizzazione"/>
                                                <CheckBox x:Name="chkSvcSmartCard" Content="Smart card"/>
                                                <CheckBox x:Name="chkSvcParental" Content="Controllo genitori e programma Insider"/>
                                                <CheckBox x:Name="chkSvcHyperV" Content="Servizi Hyper-V (se non usi macchine virtuali)"/>
                                                <CheckBox x:Name="chkSvcPrint" Tag="risky" Content="Spooler di stampa — rischioso: niente stampanti"/>
                                                <CheckBox x:Name="chkSvcSearch" Tag="risky" Content="Ricerca di Windows — rischioso: niente ricerca nel menu Start"/>
                                                <CheckBox x:Name="chkSvcRemote" Tag="risky" Content="Desktop remoto e registro remoto — rischioso se ti colleghi da fuori"/>
                                                <CheckBox x:Name="chkSvcBiometric" Tag="risky" Content="Biometria — rischioso: niente Windows Hello"/>
                                                <CheckBox x:Name="chkSvcTouch" Tag="risky" Content="Penna e tastiera su schermo — rischioso sui portatili touch"/>
                                            </StackPanel>
                                        </Border>

                                        <Border Style="{StaticResource Glass}">
                                            <StackPanel>
                                                <TextBlock x:Name="ttlMem" Text="MEMORIA E PROCESSI" Style="{StaticResource CardTitle}"/>
                                                <CheckBox x:Name="chkPrefetch" Content="Prefetch e Superfetch nel registro"/>
                                                <CheckBox x:Name="chkFth" Content="Fault Tolerant Heap — niente correzioni automatiche"/>
                                                <CheckBox x:Name="chkAppCompat" Content="Motore di compatibilità e inventario programmi"/>
                                                <CheckBox x:Name="chkSvcHostSplit" Content="Meno processi svchost (accorpa i servizi)"/>
                                                <CheckBox x:Name="chkMemCompression" Tag="risky" Content="Compressione della memoria — rischioso sotto 16 GB di RAM"/>
                                            </StackPanel>
                                        </Border>
                                    </StackPanel>

                                    <StackPanel Grid.Column="2">
                                        <Border Style="{StaticResource Glass}">
                                            <StackPanel>
                                                <Grid>
                                                    <Grid.ColumnDefinitions>
                                                        <ColumnDefinition Width="*"/>
                                                        <ColumnDefinition Width="Auto"/>
                                                    </Grid.ColumnDefinitions>
                                                    <TextBlock Grid.Column="0" x:Name="ttlBoot" Text="AVVIO DEL SISTEMA" Style="{StaticResource CardTitle}"/>
                                                    <Button Grid.Column="1" x:Name="btnBootReset" Content="Ripristina" Style="{StaticResource GhostBtn}" VerticalAlignment="Top" Margin="0,-4,0,0"/>
                                                </Grid>
                                                <TextBlock x:Name="lblBootHint" Style="{StaticResource SubTitle}" Margin="0,0,0,10"
                                                           Text="Modifiche alla configurazione di avvio. Il pulsante Ripristina rimette i valori predefiniti di Windows."/>
                                                <CheckBox x:Name="chkBootQuiet" Content="Avvio senza logo animato"/>
                                                <CheckBox x:Name="chkBootMenu" Content="Menu di avvio classico (F8 disponibile)"/>
                                                <CheckBox x:Name="chkBootTimeout" Content="Nessuna attesa nel menu di avvio"/>
                                                <CheckBox x:Name="chkBootDynTick" Tag="risky" Content="Tick dinamico del kernel — rischioso: provalo e misura"/>
                                                <CheckBox x:Name="chkBootTsc" Tag="risky" Content="Sincronizzazione TSC potenziata — rischioso: provala e misura"/>
                                            </StackPanel>
                                        </Border>

                                        <Border Style="{StaticResource Glass}">
                                            <StackPanel>
                                                <TextBlock x:Name="ttlAdvCompat" Text="OROLOGIO E PERIFERICHE" Style="{StaticResource CardTitle}"/>
                                                <CheckBox x:Name="chkAdvUtc" Content="Orologio del BIOS in UTC (doppio avvio con Linux)"/>
                                                <CheckBox x:Name="chkAdvRazer" Content="Niente installazione automatica del software Razer"/>
                                                <CheckBox x:Name="chkAdvLogi" Content="Niente assistente download Logitech"/>
                                            </StackPanel>
                                        </Border>

                                        <Border Style="{StaticResource Glass}">
                                            <StackPanel>
                                                <TextBlock x:Name="ttlAppx" Text="APP PREINSTALLATE" Style="{StaticResource CardTitle}"/>
                                                <TextBlock x:Name="lblAppxHint" Style="{StaticResource SubTitle}" Margin="0,0,0,10"
                                                           Text="Si reinstallano dallo Store quando servono."/>
                                                <CheckBox x:Name="chkAppxBloat" Content="App non essenziali (notizie, meteo, mappe, Skype...)"/>
                                                <CheckBox x:Name="chkAppxXbox" Content="App Xbox e overlay di gioco"/>
                                                <CheckBox x:Name="chkAppxProvision" Content="Non ripristinarle per i nuovi utenti"/>
                                            </StackPanel>
                                        </Border>

                                        <Border Style="{StaticResource Glass}">
                                            <StackPanel>
                                                <TextBlock x:Name="ttlSec" Text="SICUREZZA RIDOTTA" Style="{StaticResource CardTitle}" Foreground="#FFFF6B6B"/>
                                                <TextBlock x:Name="lblSecHint" Style="{StaticResource SubTitle}" Margin="0,0,0,10"
                                                           Text="Tutte rischiose e mai incluse in «Seleziona tutto». Abbassano davvero le difese del computer: usale solo su una macchina che non naviga e non apre allegati."/>
                                                <CheckBox x:Name="chkSecSmartScreen" Tag="risky" Content="SmartScreen — controllo dei file scaricati"/>
                                                <CheckBox x:Name="chkSecSpectre" Tag="risky" Content="Mitigazioni Spectre e Meltdown"/>
                                                <CheckBox x:Name="chkSecDefenderIdle" Tag="risky" Content="Defender: scansioni solo a computer fermo, CPU al 20%"/>
                                            </StackPanel>
                                        </Border>
                                    </StackPanel>
                                </Grid>
                                </StackPanel>
                            </ScrollViewer>
                            <ScrollViewer x:Name="pageSched" Visibility="Collapsed" VerticalScrollBarVisibility="Auto" Padding="0,0,6,0">
                                <ScrollViewer.Resources>
                                    <SolidColorBrush x:Key="PA" Color="#FFA3E635"/>
                                    <SolidColorBrush x:Key="PASoft" Color="#24A3E635"/>
                                    <LinearGradientBrush x:Key="PACard" StartPoint="0,0" EndPoint="0.7,1">
                                        <GradientStop Color="#16A3E635" Offset="0"/>
                                        <GradientStop Color="#0CFFFFFF" Offset="0.5"/>
                                    </LinearGradientBrush>
                                </ScrollViewer.Resources>
                                <Grid>
                                    <Grid.ColumnDefinitions>
                                        <ColumnDefinition Width="5*"/>
                                        <ColumnDefinition Width="6*"/>
                                    </Grid.ColumnDefinitions>

                                    <StackPanel Grid.Column="0">
                                        <Border Style="{StaticResource Glass}">
                                            <StackPanel>
                                                <TextBlock x:Name="ttlPs" Text="PRIORITA DEL PROCESSORE" Style="{StaticResource CardTitle}"/>
                                                <TextBlock x:Name="lblPsHint" Style="{StaticResource SubTitle}" Margin="0,0,0,12"
                                                           Text="Decide quanto tempo di processore ricevono i programmi e quanto vantaggio ha la finestra in primo piano. Vale subito, senza riavvio."/>
                                                <TextBlock x:Name="lblPsCurrent" Text="Valore attuale" Style="{StaticResource FieldLabel}" Margin="0,0,0,6"/>
                                                <Border Style="{StaticResource GlassInner}" Padding="12,9" Margin="0,0,0,14">
                                                    <TextBlock x:Name="txtPsCurrent" Text="-" Foreground="{DynamicResource PA}"
                                                               FontFamily="Consolas, Courier New" FontSize="11.5" TextWrapping="Wrap"/>
                                                </Border>
                                                <TextBlock x:Name="lblPsPreset" Text="Profilo" Style="{StaticResource FieldLabel}" Margin="0,0,0,6"/>
                                                <ComboBox x:Name="cmbPsPreset" Margin="0,0,0,10">
                                                    <ComboBoxItem x:Name="psI02" Tag="2" Content="0x02 · Predefinito di Windows"/>
                                                    <ComboBoxItem x:Name="psI26" Tag="38" Content="0x26 · Breve, variabile, primo piano 3:1 (giochi)"/>
                                                    <ComboBoxItem x:Name="psI28" Tag="40" Content="0x28 · Breve, fisso, nessun vantaggio"/>
                                                    <ComboBoxItem x:Name="psI2A" Tag="42" Content="0x2A · Breve, fisso, primo piano 3:1"/>
                                                    <ComboBoxItem x:Name="psI24" Tag="36" Content="0x24 · Breve, variabile, nessun vantaggio"/>
                                                    <ComboBoxItem x:Name="psI16" Tag="22" Content="0x16 · Lungo, variabile, primo piano 3:1"/>
                                                    <ComboBoxItem x:Name="psI18" Tag="24" Content="0x18 · Lungo, fisso (server)"/>
                                                    <ComboBoxItem x:Name="psICustom" Tag="-1" Content="Personalizzato"/>
                                                </ComboBox>
                                                <Grid Margin="0,0,0,10">
                                                    <Grid.ColumnDefinitions>
                                                        <ColumnDefinition Width="*"/>
                                                        <ColumnDefinition Width="110"/>
                                                    </Grid.ColumnDefinitions>
                                                    <TextBlock x:Name="lblPsCustom" Text="Valore esadecimale" Style="{StaticResource FieldLabel}"/>
                                                    <TextBox x:Name="txtPsCustom" Grid.Column="1" Height="34" Padding="10,0" Text="26" IsEnabled="False"/>
                                                </Grid>
                                                <Border Style="{StaticResource GlassInner}" Padding="12,9" Margin="0,0,0,14">
                                                    <TextBlock x:Name="txtPsDecoded" Text="-" Foreground="#FFC4C4CC"
                                                               FontFamily="Consolas, Courier New" FontSize="11.5" TextWrapping="Wrap"/>
                                                </Border>
                                                <Grid>
                                                    <Grid.ColumnDefinitions>
                                                        <ColumnDefinition Width="*"/>
                                                        <ColumnDefinition Width="10"/>
                                                        <ColumnDefinition Width="*"/>
                                                    </Grid.ColumnDefinitions>
                                                    <Button x:Name="btnPsDefault" Grid.Column="0" Style="{StaticResource GhostBtn}" Content="Predefinito"/>
                                                    <Button x:Name="btnPsApply" Grid.Column="2" Style="{StaticResource PrimaryBtn}" FontSize="13" Content="Applica"/>
                                                </Grid>
                                            </StackPanel>
                                        </Border>
                                    </StackPanel>

                                    <StackPanel Grid.Column="1">
                                        <Border Style="{StaticResource Glass}">
                                            <StackPanel>
                                                <Grid>
                                                    <Grid.ColumnDefinitions>
                                                        <ColumnDefinition Width="*"/>
                                                        <ColumnDefinition Width="Auto"/>
                                                    </Grid.ColumnDefinitions>
                                                    <TextBlock x:Name="ttlMm" Text="MULTIMEDIA CLASS SCHEDULER" Style="{StaticResource CardTitle}"/>
                                                    <Button x:Name="btnMmReload" Grid.Column="1" Style="{StaticResource GhostBtn}" Content="Rileggi" VerticalAlignment="Top" Margin="0,-4,0,0"/>
                                                </Grid>
                                                <TextBlock x:Name="lblMmHint" Style="{StaticResource SubTitle}" Margin="0,0,0,12"
                                                           Text="Il servizio di Windows che dà la precedenza a giochi, audio e video. Le modifiche valgono dal prossimo riavvio."/>
                                                <Grid>
                                                    <Grid.ColumnDefinitions>
                                                        <ColumnDefinition Width="*"/>
                                                        <ColumnDefinition Width="190"/>
                                                    </Grid.ColumnDefinitions>
                                                    <Grid.RowDefinitions>
                                                        <RowDefinition Height="Auto"/>
                                                        <RowDefinition Height="Auto"/>
                                                        <RowDefinition Height="Auto"/>
                                                        <RowDefinition Height="Auto"/>
                                                        <RowDefinition Height="Auto"/>
                                                        <RowDefinition Height="Auto"/>
                                                        <RowDefinition Height="Auto"/>
                                                        <RowDefinition Height="Auto"/>
                                                        <RowDefinition Height="Auto"/>
                                                        <RowDefinition Height="Auto"/>
                                                        <RowDefinition Height="Auto"/>
                                                        <RowDefinition Height="Auto"/>
                                                        <RowDefinition Height="Auto"/>
                                                    </Grid.RowDefinitions>
                                                    <TextBlock x:Name="lblMmNet" Grid.Row="0" Text="Limitazione della rete" Style="{StaticResource FieldLabel}"/>
                                                    <ComboBox x:Name="cmbMmNet" Grid.Row="0" Grid.Column="1" Margin="0,3"/>
                                                    <TextBlock x:Name="lblMmResp" Grid.Row="1" Text="CPU riservata al sistema" Style="{StaticResource FieldLabel}"/>
                                                    <ComboBox x:Name="cmbMmResp" Grid.Row="1" Grid.Column="1" Margin="0,3"/>
                                                    <Separator Grid.Row="2" Grid.ColumnSpan="2" Style="{StaticResource SoftSep}"/>
                                                    <TextBlock x:Name="lblMmTask" Grid.Row="3" Text="Attività" Style="{StaticResource FieldLabel}" FontWeight="SemiBold"/>
                                                    <ComboBox x:Name="cmbMmTask" Grid.Row="3" Grid.Column="1" Margin="0,3"/>
                                                    <TextBlock x:Name="lblMmAffinity" Grid.Row="4" Text="Affinità (esadecimale, 0 = tutti i core)" Style="{StaticResource FieldLabel}"/>
                                                    <TextBox x:Name="txtMmAffinity" Grid.Row="4" Grid.Column="1" Margin="0,3" Height="34" Padding="10,0"/>
                                                    <TextBlock x:Name="lblMmClock" Grid.Row="5" Text="Clock rate (100 ns)" Style="{StaticResource FieldLabel}"/>
                                                    <TextBox x:Name="txtMmClock" Grid.Row="5" Grid.Column="1" Margin="0,3" Height="34" Padding="10,0"/>
                                                    <TextBlock x:Name="lblMmGpu" Grid.Row="6" Text="Priorità GPU" Style="{StaticResource FieldLabel}"/>
                                                    <ComboBox x:Name="cmbMmGpu" Grid.Row="6" Grid.Column="1" Margin="0,3"/>
                                                    <TextBlock x:Name="lblMmPrio" Grid.Row="7" Text="Priorità" Style="{StaticResource FieldLabel}"/>
                                                    <ComboBox x:Name="cmbMmPrio" Grid.Row="7" Grid.Column="1" Margin="0,3"/>
                                                    <TextBlock x:Name="lblMmSched" Grid.Row="8" Text="Categoria di scheduling" Style="{StaticResource FieldLabel}"/>
                                                    <ComboBox x:Name="cmbMmSched" Grid.Row="8" Grid.Column="1" Margin="0,3"/>
                                                    <TextBlock x:Name="lblMmSfio" Grid.Row="9" Text="Priorità I/O" Style="{StaticResource FieldLabel}"/>
                                                    <ComboBox x:Name="cmbMmSfio" Grid.Row="9" Grid.Column="1" Margin="0,3"/>
                                                    <TextBlock x:Name="lblMmBgOnly" Grid.Row="10" Text="Solo in background" Style="{StaticResource FieldLabel}"/>
                                                    <ComboBox x:Name="cmbMmBgOnly" Grid.Row="10" Grid.Column="1" Margin="0,3"/>
                                                    <TextBlock x:Name="lblMmBgPrio" Grid.Row="11" Text="Priorità in background" Style="{StaticResource FieldLabel}"/>
                                                    <ComboBox x:Name="cmbMmBgPrio" Grid.Row="11" Grid.Column="1" Margin="0,3"/>
                                                    <TextBlock x:Name="lblMmLatency" Grid.Row="12" Text="Sensibile alla latenza" Style="{StaticResource FieldLabel}"/>
                                                    <ComboBox x:Name="cmbMmLatency" Grid.Row="12" Grid.Column="1" Margin="0,3"/>
                                                </Grid>
                                                <Grid Margin="0,16,0,0">
                                                    <Grid.ColumnDefinitions>
                                                        <ColumnDefinition Width="*"/>
                                                        <ColumnDefinition Width="8"/>
                                                        <ColumnDefinition Width="*"/>
                                                        <ColumnDefinition Width="8"/>
                                                        <ColumnDefinition Width="*"/>
                                                    </Grid.ColumnDefinitions>
                                                    <Button x:Name="btnMmBackup" Grid.Column="0" Style="{StaticResource GhostBtn}" Content="Salva backup"/>
                                                    <Button x:Name="btnMmDefault" Grid.Column="2" Style="{StaticResource GhostBtn}" Content="Predefiniti"/>
                                                    <Button x:Name="btnMmApply" Grid.Column="4" Style="{StaticResource PrimaryBtn}" FontSize="13" Content="Salva"/>
                                                </Grid>
                                            </StackPanel>
                                        </Border>
                                    </StackPanel>
                                </Grid>
                            </ScrollViewer>

                            <Grid x:Name="pagePriv2" Visibility="Collapsed">
                                <Grid.Resources>
                                    <SolidColorBrush x:Key="PA" Color="#FFC084FC"/>
                                    <SolidColorBrush x:Key="PASoft" Color="#24C084FC"/>
                                    <LinearGradientBrush x:Key="PACard" StartPoint="0,0" EndPoint="0.7,1">
                                        <GradientStop Color="#16C084FC" Offset="0"/>
                                        <GradientStop Color="#0CFFFFFF" Offset="0.5"/>
                                    </LinearGradientBrush>
                                </Grid.Resources>
                                <Grid x:Name="catPriv"/>
                            </Grid>

                            <Grid x:Name="pageExp" Visibility="Collapsed">
                                <Grid.Resources>
                                    <SolidColorBrush x:Key="PA" Color="#FF2DD4BF"/>
                                    <SolidColorBrush x:Key="PASoft" Color="#242DD4BF"/>
                                    <LinearGradientBrush x:Key="PACard" StartPoint="0,0" EndPoint="0.7,1">
                                        <GradientStop Color="#162DD4BF" Offset="0"/>
                                        <GradientStop Color="#0CFFFFFF" Offset="0.5"/>
                                    </LinearGradientBrush>
                                </Grid.Resources>
                                <Grid x:Name="catExp"/>
                            </Grid>

                            <Grid x:Name="pageTask" Visibility="Collapsed">
                                <Grid.Resources>
                                    <SolidColorBrush x:Key="PA" Color="#FF60A5FA"/>
                                    <SolidColorBrush x:Key="PASoft" Color="#2460A5FA"/>
                                    <LinearGradientBrush x:Key="PACard" StartPoint="0,0" EndPoint="0.7,1">
                                        <GradientStop Color="#1660A5FA" Offset="0"/>
                                        <GradientStop Color="#0CFFFFFF" Offset="0.5"/>
                                    </LinearGradientBrush>
                                </Grid.Resources>
                                <Grid x:Name="catTask"/>
                            </Grid>

                            <Grid x:Name="pageNotif" Visibility="Collapsed">
                                <Grid.Resources>
                                    <SolidColorBrush x:Key="PA" Color="#FFFB7185"/>
                                    <SolidColorBrush x:Key="PASoft" Color="#24FB7185"/>
                                    <LinearGradientBrush x:Key="PACard" StartPoint="0,0" EndPoint="0.7,1">
                                        <GradientStop Color="#16FB7185" Offset="0"/>
                                        <GradientStop Color="#0CFFFFFF" Offset="0.5"/>
                                    </LinearGradientBrush>
                                </Grid.Resources>
                                <Grid x:Name="catNotif"/>
                            </Grid>

                            <Grid x:Name="pageGame" Visibility="Collapsed">
                                <Grid.Resources>
                                    <SolidColorBrush x:Key="PA" Color="#FFE879F9"/>
                                    <SolidColorBrush x:Key="PASoft" Color="#24E879F9"/>
                                    <LinearGradientBrush x:Key="PACard" StartPoint="0,0" EndPoint="0.7,1">
                                        <GradientStop Color="#16E879F9" Offset="0"/>
                                        <GradientStop Color="#0CFFFFFF" Offset="0.5"/>
                                    </LinearGradientBrush>
                                </Grid.Resources>
                                <Grid x:Name="catGame"/>
                            </Grid>

                            <Grid x:Name="pageWin" Visibility="Collapsed">
                                <Grid.Resources>
                                    <SolidColorBrush x:Key="PA" Color="#FF94A3B8"/>
                                    <SolidColorBrush x:Key="PASoft" Color="#2494A3B8"/>
                                    <LinearGradientBrush x:Key="PACard" StartPoint="0,0" EndPoint="0.7,1">
                                        <GradientStop Color="#1694A3B8" Offset="0"/>
                                        <GradientStop Color="#0CFFFFFF" Offset="0.5"/>
                                    </LinearGradientBrush>
                                </Grid.Resources>
                                <Grid x:Name="catWin"/>
                            </Grid>

                            <Grid x:Name="pageTools" Visibility="Collapsed">
                                <Grid.Resources>
                                    <SolidColorBrush x:Key="PA" Color="#FF2DD4BF"/>
                                    <SolidColorBrush x:Key="PASoft" Color="#242DD4BF"/>
                                    <LinearGradientBrush x:Key="PACard" StartPoint="0,0" EndPoint="0.7,1">
                                        <GradientStop Color="#162DD4BF" Offset="0"/>
                                        <GradientStop Color="#0CFFFFFF" Offset="0.5"/>
                                    </LinearGradientBrush>
                                </Grid.Resources>
                                <Grid.RowDefinitions>
                                    <RowDefinition Height="Auto"/>
                                    <RowDefinition Height="*"/>
                                </Grid.RowDefinitions>
                                <Border x:Name="bdToolJobs" Grid.Row="0" Style="{StaticResource Glass}" Padding="18,14,18,12" Visibility="Collapsed">
                                    <StackPanel>
                                        <Grid Margin="0,0,0,8">
                                            <Grid.ColumnDefinitions>
                                                <ColumnDefinition Width="Auto"/>
                                                <ColumnDefinition Width="*"/>
                                                <ColumnDefinition Width="Auto"/>
                                            </Grid.ColumnDefinitions>
                                            <TextBlock x:Name="ttlToolJobs" Text="OPERAZIONI" Style="{StaticResource CardTitle}" Margin="0" VerticalAlignment="Center"/>
                                            <TextBlock x:Name="txtToolJobsCount" Grid.Column="1" Foreground="{DynamicResource PA}" FontFamily="Roboto, Segoe UI"
                                                       FontSize="12" Margin="12,0,0,0" VerticalAlignment="Center"/>
                                            <Button x:Name="btnToolJobsClose" Grid.Column="2" Style="{StaticResource DotBtn}" Content="Chiudi" Visibility="Collapsed"/>
                                        </Grid>
                                        <ProgressBar x:Name="prgToolJobs" Height="5" Minimum="0" Maximum="1" Value="0" Margin="0,0,0,10"/>
                                        <ScrollViewer MaxHeight="170" VerticalScrollBarVisibility="Auto">
                                            <StackPanel x:Name="panToolJobs"/>
                                        </ScrollViewer>
                                    </StackPanel>
                                </Border>
                                <ScrollViewer x:Name="svTools" Grid.Row="1" VerticalScrollBarVisibility="Auto" Padding="0,0,6,0">
                                    <Grid x:Name="panTools"/>
                                </ScrollViewer>
                            </Grid>

                            <Grid x:Name="pageApps" Visibility="Collapsed">
                                <Grid.Resources>
                                    <SolidColorBrush x:Key="PA" Color="#FFFDBA74"/>
                                    <SolidColorBrush x:Key="PASoft" Color="#24FDBA74"/>
                                    <LinearGradientBrush x:Key="PACard" StartPoint="0,0" EndPoint="0.7,1">
                                        <GradientStop Color="#16FDBA74" Offset="0"/>
                                        <GradientStop Color="#0CFFFFFF" Offset="0.5"/>
                                    </LinearGradientBrush>
                                </Grid.Resources>
                                <Grid.RowDefinitions>
                                    <RowDefinition Height="Auto"/>
                                    <RowDefinition Height="Auto"/>
                                    <RowDefinition Height="*"/>
                                </Grid.RowDefinitions>
                                <StackPanel Grid.Row="0" Margin="7,0,7,6">
                                    <WrapPanel>
                                        <RadioButton x:Name="radAppsCatalog" GroupName="AppsView" Content="Catalogo" IsChecked="True" Margin="0,4,4,8"/>
                                        <RadioButton x:Name="radAppsInstalled" GroupName="AppsView" Content="Installate" Margin="0,4,14,8"/>
                                        <Grid Margin="0,0,10,8">
                                            <TextBox x:Name="txtAppSearch" Width="220" Height="34" Padding="10,0" VerticalContentAlignment="Center"/>
                                            <TextBlock x:Name="lblAppSearchHint" Text="Cerca..." Foreground="#FF6E6E78" IsHitTestVisible="False"
                                                       Margin="12,0,0,0" VerticalAlignment="Center"/>
                                        </Grid>
                                        <ComboBox x:Name="cmbAppCategory" Width="190" Margin="0,0,10,8" VerticalAlignment="Center"/>
                                        <ComboBox x:Name="cmbAppLicense" Width="170" Margin="0,0,10,8" VerticalAlignment="Center"/>
                                    </WrapPanel>
                                    <WrapPanel>
                                        <Button x:Name="btnAppsAction" Style="{StaticResource DotBtn}" Content="Installa selezionate" Margin="0,0,8,8"/>
                                        <Button x:Name="btnAppsUpgrade" Style="{StaticResource DotBtn}" Content="Aggiorna selezionate" Margin="0,0,8,8"/>
                                        <Button x:Name="btnAppsClear" Style="{StaticResource DotBtn}" Content="Deseleziona" Margin="0,0,8,8"/>
                                        <Button x:Name="btnAppsRefresh" Style="{StaticResource DotBtn}" Content="Aggiorna elenco" Margin="0,0,14,8"/>
                                        <TextBlock x:Name="txtAppsStatus" Style="{StaticResource SubTitle}" VerticalAlignment="Center" Margin="0,0,0,8" TextWrapping="Wrap"/>
                                    </WrapPanel>
                                </StackPanel>
                                <!-- Operazioni in corso: una riga per app, con barra di download e di installazione. -->
                                <Border x:Name="bdAppJobs" Grid.Row="1" Style="{StaticResource Glass}" Padding="18,14,18,12" Visibility="Collapsed">
                                    <StackPanel>
                                        <Grid Margin="0,0,0,8">
                                            <Grid.ColumnDefinitions>
                                                <ColumnDefinition Width="Auto"/>
                                                <ColumnDefinition Width="*"/>
                                                <ColumnDefinition Width="Auto"/>
                                            </Grid.ColumnDefinitions>
                                            <TextBlock x:Name="ttlAppJobs" Text="OPERAZIONI" Style="{StaticResource CardTitle}" Margin="0" VerticalAlignment="Center"/>
                                            <TextBlock x:Name="txtAppJobsCount" Grid.Column="1" Foreground="{DynamicResource PA}" FontFamily="Roboto, Segoe UI"
                                                       FontSize="12" Margin="12,0,0,0" VerticalAlignment="Center"/>
                                            <Button x:Name="btnAppJobsClose" Grid.Column="2" Style="{StaticResource DotBtn}" Content="Chiudi" Visibility="Collapsed"/>
                                        </Grid>
                                        <ProgressBar x:Name="prgAppJobs" Height="5" Minimum="0" Maximum="1" Value="0" Margin="0,0,0,10"/>
                                        <ScrollViewer MaxHeight="200" VerticalScrollBarVisibility="Auto">
                                            <StackPanel x:Name="panAppJobs"/>
                                        </ScrollViewer>
                                    </StackPanel>
                                </Border>
                                <ScrollViewer Grid.Row="2" x:Name="svApps" VerticalScrollBarVisibility="Auto" Padding="0,0,6,0">
                                    <Grid x:Name="panApps"/>
                                </ScrollViewer>
                            </Grid>


                        </Grid>

                        <!-- Barra in basso su due righe: avanzamento sopra, pulsanti sotto.
                             Su una riga sola i testi lunghi (francese, russo) tagliavano «Applica». -->
                        <Border Grid.Row="2" Style="{StaticResource Bar}" Margin="7,12,7,0" Padding="18,12,18,13">
                            <Grid>
                                <Grid.RowDefinitions>
                                    <RowDefinition Height="Auto"/>
                                    <RowDefinition Height="Auto"/>
                                </Grid.RowDefinitions>

                                <Grid Grid.Row="0">
                                    <Grid.ColumnDefinitions>
                                        <ColumnDefinition Width="*"/>
                                        <ColumnDefinition Width="Auto"/>
                                    </Grid.ColumnDefinitions>
                                    <StackPanel Grid.Column="0" VerticalAlignment="Center" Margin="2,0,24,0">
                                        <Grid>
                                            <Grid.ColumnDefinitions>
                                                <ColumnDefinition Width="*"/>
                                                <ColumnDefinition Width="Auto"/>
                                            </Grid.ColumnDefinitions>
                                            <TextBlock x:Name="txtProgressLabel" Grid.Column="0" Text="Pronto." Foreground="#FFF2F2F5"
                                                       FontFamily="Roboto, Segoe UI" FontSize="12.5" TextTrimming="CharacterEllipsis"/>
                                            <TextBlock x:Name="txtProgressCount" Grid.Column="1" Text="" Foreground="{DynamicResource PA}"
                                                       FontFamily="Roboto, Segoe UI" FontSize="12.5" Margin="12,0,0,0"/>
                                        </Grid>
                                        <ProgressBar x:Name="prgTweaks" Height="5" Margin="0,7,0,0" Minimum="0" Maximum="1" Value="0"/>
                                    </StackPanel>
                                    <CheckBox x:Name="chkRestorePoint" Grid.Column="1" Content="Punto di ripristino"
                                              VerticalAlignment="Center" Margin="0,-4,0,-4"/>
                                </Grid>

                                <Grid x:Name="barQueue" Grid.Row="1" Margin="0,10,0,0">
                                    <Grid.ColumnDefinitions>
                                        <ColumnDefinition Width="*"/>
                                        <ColumnDefinition Width="Auto"/>
                                    </Grid.ColumnDefinitions>
                                    <WrapPanel Grid.Column="0" Orientation="Horizontal">
                                        <Button x:Name="btnSelectAll" Style="{StaticResource GhostBtn}" Height="40" Margin="0,0,8,4" Content="Seleziona tutto"/>
                                        <Button x:Name="btnSelectPage" Style="{StaticResource GhostBtn}" Height="40" Margin="0,0,8,4" Content="Questa pagina"/>
                                        <Button x:Name="btnRecommended" Style="{StaticResource GhostBtn}" Height="40" Margin="0,0,8,4" Content="Consigliati"/>
                                        <Button x:Name="btnDeselectAll" Style="{StaticResource GhostBtn}" Height="40" Margin="0,0,8,4" Content="Deseleziona"/>
                                    </WrapPanel>
                                    <StackPanel Grid.Column="1" Orientation="Horizontal">
                                        <Button x:Name="btnUndo" Style="{StaticResource UndoBtn}" Height="40" MinWidth="150" Margin="0,0,8,0" Content="Reimposta predefiniti"/>
                                        <Button x:Name="btnRun" Style="{StaticResource PrimaryBtn}" Height="40" MinWidth="170" Content="Applica modifiche"/>
                                    </StackPanel>
                                </Grid>
                            </Grid>
                        </Border>
                    </Grid>
                </Grid>
            </Grid>
            <Border x:Name="dimmer" Background="#B3000000" Visibility="Collapsed"/>
        </Grid>
    </Border>
</Window>
'@
